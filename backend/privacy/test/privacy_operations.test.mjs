import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DEFAULT_PRIVACY_MANIFEST,
  DeterministicAuthDeletionGateway,
  DeterministicReceiptIdGenerator,
  DeterministicSessionGateway,
  FixedServerClock,
  InMemoryPrivacyStorage,
  PrivacyBackendFailure,
  PrivacyOperationProcessor,
  createPrivacyManifest,
} from '../src/index.mjs';

const instant = new Date('2026-08-17T15:00:00.000Z');
const owner = 'synthetic-owner';
const anotherOwner = 'synthetic-another-owner';

function fixture({ batchSize = 2 } = {}) {
  const storage = new InMemoryPrivacyStorage();
  const clock = new FixedServerClock(instant);
  const sessions = new DeterministicSessionGateway();
  const auth = new DeterministicAuthDeletionGateway();
  const processor = new PrivacyOperationProcessor({
    storage, clock, sessionGateway: sessions, authGateway: auth,
    receiptIdGenerator: new DeterministicReceiptIdGenerator(), batchSize,
  });
  return { storage, clock, sessions, auth, processor };
}

const actorFor = (uid = owner, overrides = {}) => ({
  uid, authenticated: true, appCheckVerified: true, emailVerified: true,
  legalProfileVerified: true, authenticatedAt: new Date(instant), ...overrides,
});

const phraseFor = (type) => type === 'financialReset' ? 'RESETAR DADOS FINANCEIROS' : 'EXCLUIR MINHA CONTA';

async function seedAll(storage, uid = owner) {
  for (const target of DEFAULT_PRIVACY_MANIFEST.accountDeletion) {
    await storage.seed({ target, ownerId: uid, documentId: `document-${target}` });
  }
}

async function request(processor, type, uid = owner, key = 'synthetic-idempotency-key-0001') {
  return processor.request({ actor: actorFor(uid), type, confirmationPhrase: phraseFor(type), idempotencyKey: key });
}

async function complete(processor, operationId, uid = owner) {
  let result;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    result = await processor.advance({ actor: actorFor(uid), operationId });
    if (result.state === 'completed') return result;
  }
  throw new Error('privacy operation did not complete');
}

async function beginDeleting(processor, operationId, uid = owner) {
  await processor.advance({ actor: actorFor(uid), operationId });
  await processor.advance({ actor: actorFor(uid), operationId });
  return processor.advance({ actor: actorFor(uid), operationId });
}

test('financial reset deletes exactly the closed nine-target manifest and preserves identity, Premium and owner', async () => {
  const { storage, processor } = fixture();
  await seedAll(storage);
  await storage.seed({ target: 'accounts', ownerId: anotherOwner, documentId: 'another-account' });
  const started = await request(processor, 'financialReset');
  assert.equal(started.state, 'prepared');
  const confirmed = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(confirmed.state, 'confirmed');
  const locked = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(locked.state, 'locked');
  assert.equal(await storage.writeAllowed({ target: 'transactions', ownerId: owner }), false);
  assert.equal(await storage.writeAllowed({ target: 'premiumEntitlement', ownerId: owner }), true);
  const completed = await complete(processor, started.operationId);
  assert.equal(completed.receipt.result, 'resetCompleted');
  for (const target of DEFAULT_PRIVACY_MANIFEST.financialReset) assert.equal((await storage.listOwned(target, owner)).length, 0);
  for (const target of ['userProfile', 'premiumEntitlement', 'systemAdmin', 'premiumClosedTestGrants']) {
    assert.equal((await storage.listOwned(target, owner)).length, 1);
  }
  assert.equal((await storage.listOwned('accounts', anotherOwner)).length, 1);
});

test('account deletion removes every manifest target, locks all writes, revokes sessions then deletes Auth', async () => {
  const { storage, processor, sessions, auth } = fixture();
  await seedAll(storage);
  const started = await request(processor, 'accountDeletion');
  await processor.advance({ actor: actorFor(), operationId: started.operationId });
  await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(await storage.writeAllowed({ target: 'premiumEntitlement', ownerId: owner }), false);
  const completed = await complete(processor, started.operationId);
  assert.equal(completed.receipt.result, 'accountDeleted');
  assert.deepEqual(sessions.calls, [owner]);
  assert.deepEqual(auth.calls, [owner]);
  for (const target of DEFAULT_PRIVACY_MANIFEST.accountDeletion) assert.equal((await storage.listOwned(target, owner)).length, 0);
  const state = await storage.snapshot();
  assert.equal(state.activeByOwner.has(owner), false);
  assert.equal(state.locks.has(owner), false);
  assert.equal(state.audits[0].ownerId, undefined);
});

test('repetition returns the same active operation and concurrent reset/delete are refused', async () => {
  const { processor } = fixture();
  const first = await request(processor, 'financialReset');
  const repeated = await request(processor, 'financialReset');
  assert.equal(repeated.operationId, first.operationId);
  await assert.rejects(
    () => request(processor, 'accountDeletion', owner, 'synthetic-idempotency-key-0002'),
    (error) => error instanceof PrivacyBackendFailure && error.code === 'privacy_operation_conflict',
  );
});

test('cursor resumes exactly after timeout committed after a conservative batch', async () => {
  const { storage, processor } = fixture({ batchSize: 1 });
  for (const documentId of ['a', 'b', 'c']) await storage.seed({ target: 'accounts', ownerId: owner, documentId });
  const started = await request(processor, 'financialReset');
  await beginDeleting(processor, started.operationId);
  storage.failAfterCommit = true;
  const afterTimeout = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(afterTimeout.state, 'deleting');
  assert.equal((await storage.listOwned('accounts', owner)).length, 2);
  const completed = await complete(processor, started.operationId);
  assert.equal(completed.state, 'completed');
  assert.equal((await storage.listOwned('accounts', owner)).length, 0);
});

test('failure before a batch preserves the cursor and retry resumes only the persisted operation', async () => {
  const { storage, processor } = fixture({ batchSize: 1 });
  await storage.seed({ target: 'accounts', ownerId: owner, documentId: 'a' });
  const started = await request(processor, 'financialReset');
  await beginDeleting(processor, started.operationId);
  storage.failBeforeCommit = true;
  await assert.rejects(() => processor.advance({ actor: actorFor(), operationId: started.operationId }));
  assert.equal((await storage.listOwned('accounts', owner)).length, 1);
  await complete(processor, started.operationId);
  assert.equal((await storage.listOwned('accounts', owner)).length, 0);
});

test('invalid cursor and incomplete or unknown manifest fail closed', async () => {
  const { storage, processor } = fixture();
  const started = await request(processor, 'financialReset');
  await beginDeleting(processor, started.operationId);
  await storage.transaction((draft) => { draft.operations.get(started.operationId).cursor = { targetIndex: -1, afterDocumentId: null }; });
  await assert.rejects(
    () => processor.advance({ actor: actorFor(), operationId: started.operationId }),
    (error) => error instanceof PrivacyBackendFailure && error.code === 'privacy_cursor_invalid',
  );
  assert.throws(() => createPrivacyManifest({ financialReset: ['accounts'], accountDeletion: DEFAULT_PRIVACY_MANIFEST.accountDeletion }), /privacy_manifest_incomplete/);
  assert.throws(() => createPrivacyManifest({ financialReset: DEFAULT_PRIVACY_MANIFEST.financialReset, accountDeletion: [...DEFAULT_PRIVACY_MANIFEST.accountDeletion, 'unknown'] }), /privacy_manifest_unknown_target/);
});

test('cross-UID, owner-shaped actor, stale login, missing App Check and wrong phrase never start an operation', async () => {
  const { processor } = fixture();
  for (const actor of [
    actorFor(owner, { uid: '', isOwner: true }), actorFor(owner, { appCheckVerified: false }),
    actorFor(owner, { authenticatedAt: new Date(instant.getTime() - 300001) }),
  ]) {
    await assert.rejects(() => processor.request({ actor, type: 'financialReset', confirmationPhrase: phraseFor('financialReset'), idempotencyKey: 'synthetic-idempotency-key-0001' }));
  }
  const started = await request(processor, 'financialReset');
  await assert.rejects(
    () => processor.advance({ actor: actorFor(anotherOwner, { isOwner: true }), operationId: started.operationId }),
    (error) => error instanceof PrivacyBackendFailure && error.code === 'privacy_operation_not_found',
  );
  await assert.rejects(() => processor.request({ actor: actorFor(), type: 'financialReset', confirmationPhrase: 'RESET', idempotencyKey: 'synthetic-idempotency-key-else' }));
});

test('session and Auth failures are recoverable; Auth is not called before session revocation succeeds', async () => {
  const { storage, processor, sessions, auth } = fixture();
  await seedAll(storage);
  const started = await request(processor, 'accountDeletion');
  for (let index = 0; index < 30; index += 1) {
    const current = await processor.advance({ actor: actorFor(), operationId: started.operationId });
    if (current.state === 'authDeletionPending') break;
  }
  sessions.failNext = true;
  const failedSession = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(failedSession.state, 'failed');
  assert.deepEqual(auth.calls, []);
  await processor.retry({ actor: actorFor(), operationId: started.operationId });
  await processor.advance({ actor: actorFor(), operationId: started.operationId });
  auth.failNext = true;
  const failedAuth = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(failedAuth.state, 'failed');
  await processor.retry({ actor: actorFor(), operationId: started.operationId });
  const completed = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(completed.state, 'completed');
  assert.equal(auth.attempts.length, 2);
  assert.equal(auth.calls.length, 1);
  assert.equal((await storage.snapshot()).receipts.size, 1);
});

test('confirmation lost after the idempotent Auth deletion returns the anonymous receipt without restoration', async () => {
  const { storage, processor, auth } = fixture();
  await seedAll(storage);
  const started = await request(processor, 'accountDeletion');
  for (let index = 0; index < 40; index += 1) {
    const current = await processor.advance({ actor: actorFor(), operationId: started.operationId });
    if (current.state === 'authDeletionPending' && current.revision > 20) break;
  }
  await processor.advance({ actor: actorFor(), operationId: started.operationId });
  storage.failAfterCommit = true;
  const completed = await processor.advance({ actor: actorFor(), operationId: started.operationId });
  assert.equal(completed.state, 'completed');
  assert.equal(auth.calls.length, 1);
  const state = await storage.snapshot();
  assert.equal(state.operations.get(started.operationId).ownerId, undefined);
  assert.equal(state.receipts.size, 1);
});

test('expired external lease can resume safely after a worker timeout', async () => {
  const { storage, clock, processor, sessions } = fixture();
  await seedAll(storage);
  const started = await request(processor, 'accountDeletion');
  for (let index = 0; index < 40; index += 1) {
    const current = await processor.advance({ actor: actorFor(), operationId: started.operationId });
    if (current.state === 'authDeletionPending') break;
  }
  await storage.transaction((draft) => {
    draft.operations.get(started.operationId).externalLease = { stage: 'revokeSessions', claimedAt: instant };
  });
  await assert.rejects(() => processor.advance({ actor: actorFor(), operationId: started.operationId }));
  clock.set(new Date(instant.getTime() + 30001));
  await processor.advance({ actor: actorFor(owner, { authenticatedAt: new Date(instant) }), operationId: started.operationId });
  assert.deepEqual(sessions.calls, [owner]);
});

test('completed receipt and audit contain no personal data, tokens or values and deletion never restores', async () => {
  const { storage, processor } = fixture();
  await storage.seed({ target: 'transactions', ownerId: owner, documentId: 'transaction-a', value: { amountCents: 12345, token: 'not-to-be-returned' } });
  const key = 'synthetic-idempotency-key-0001';
  const started = await request(processor, 'financialReset', owner, key);
  const completed = await complete(processor, started.operationId);
  const repeated = await request(processor, 'financialReset', owner, key);
  assert.deepEqual(repeated, completed);
  assert.equal(JSON.stringify(completed).includes(owner), false);
  assert.equal(JSON.stringify(completed).includes('12345'), false);
  assert.equal(JSON.stringify(completed).includes('not-to-be-returned'), false);
  assert.equal(JSON.stringify((await storage.snapshot()).audits).includes(owner), false);
  assert.equal((await storage.listOwned('transactions', owner)).length, 0);
});
