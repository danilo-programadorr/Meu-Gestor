import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import test from 'node:test';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import {
  DeterministicAuthDeletionGateway,
  DeterministicReceiptIdGenerator,
  DeterministicSessionGateway,
  FixedServerClock,
  OperationIdGenerator,
} from '../../../privacy/src/gateways.mjs';
import { PrivacyOperationProcessor } from '../../../privacy/src/processor.mjs';
import { FirestorePrivacyStorage } from '../src/firestore_privacy_storage.mjs';

const now = new Date('2026-10-18T12:00:00.000Z');

test('Firestore persiste reset paginado, apaga demanda derivada e preserva identidade', async () => {
  const fixture = await createFixture();
  try {
    await seedOwner(fixture.firestore, fixture.ownerId);
    await seedOwner(fixture.firestore, fixture.otherOwnerId);
    const started = await fixture.processor.request({
      actor: actor(fixture.ownerId),
      type: 'financialReset',
      confirmationPhrase: 'RESETAR DADOS FINANCEIROS',
      idempotencyKey: 'synthetic-reset-idempotency-key',
    });
    await fixture.processor.advance({ actor: actor(fixture.ownerId), operationId: started.operationId });
    const completed = await processUntilComplete(fixture.processor, fixture.ownerId, started.operationId);
    assert.equal(completed.receipt.result, 'resetCompleted');
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}/accounts/account-1`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}`).get()).exists, true);
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}/assistantSettings/remote`).get()).exists, true);
    assert.equal((await fixture.firestore.doc(`users/${fixture.otherOwnerId}/accounts/account-1`).get()).exists, true);
    assert.equal((await fixture.firestore.doc(`_marketQuoteDemands/${demandId(fixture.ownerId, 'asset-1')}`).get()).exists, false);
    assert.equal(fixture.assistantDeletes.length, 0);
  } finally {
    await deleteApp(fixture.app);
  }
});

test('Firestore conclui exclusão own-only, limpa dados atuais e mantém outro usuário', async () => {
  const fixture = await createFixture();
  try {
    await seedOwner(fixture.firestore, fixture.ownerId);
    await seedOwner(fixture.firestore, fixture.otherOwnerId);
    const started = await fixture.processor.request({
      actor: actor(fixture.ownerId),
      type: 'accountDeletion',
      confirmationPhrase: 'EXCLUIR MINHA CONTA',
      idempotencyKey: 'synthetic-delete-idempotency-key',
    });
    const repeated = await fixture.processor.request({
      actor: actor(fixture.ownerId),
      type: 'accountDeletion',
      confirmationPhrase: 'EXCLUIR MINHA CONTA',
      idempotencyKey: 'synthetic-delete-idempotency-key',
    });
    assert.equal(repeated.operationId, started.operationId);
    await assert.rejects(
      () => fixture.processor.process({
        ownerId: fixture.otherOwnerId,
        operationId: started.operationId,
      }),
      (error) => error?.code === 'privacy_operation_not_found',
    );
    await fixture.processor.advance({ actor: actor(fixture.ownerId), operationId: started.operationId });
    const completed = await processUntilComplete(fixture.processor, fixture.ownerId, started.operationId);
    assert.equal(completed.receipt.result, 'accountDeleted');
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}/assistantSettings/remote`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`users/${fixture.ownerId}/entitlements/premium`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`system_admins/${fixture.ownerId}`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`_premiumClosedTestTesters/${fixture.ownerId}`).get()).exists, false);
    assert.equal((await fixture.firestore.doc(`users/${fixture.otherOwnerId}`).get()).exists, true);
    assert.deepEqual(fixture.assistantDeletes, [fixture.ownerId]);
    assert.deepEqual(fixture.sessions.calls, [fixture.ownerId]);
    assert.deepEqual(fixture.auth.calls, [fixture.ownerId]);
    const receipt = await fixture.firestore.doc(`_privacyReceipts/${started.operationId}`).get();
    assert.equal(receipt.exists, true);
    assert.deepEqual(Object.keys(receipt.data()).sort(), [
      'completedAt', 'expiresAt', 'receiptId', 'result', 'schemaVersion', 'type',
    ]);
  } finally {
    await deleteApp(fixture.app);
  }
});

async function createFixture() {
  const suffix = randomUUID().replaceAll('-', '');
  const projectId = process.env.GCLOUD_PROJECT ?? 'demo-meu-gestor-financeiro';
  const app = initializeApp({ projectId }, `privacy-emulator-${suffix}`);
  const firestore = getFirestore(app);
  const sessions = new DeterministicSessionGateway();
  const auth = new DeterministicAuthDeletionGateway();
  const assistantDeletes = [];
  const storage = new FirestorePrivacyStorage({
    firestore,
    Timestamp,
    externalTargets: {
      assistantUsageLedger: {
        deleteOwner: async ({ ownerId }) => assistantDeletes.push(ownerId),
      },
    },
  });
  return {
    app,
    firestore,
    sessions,
    auth,
    assistantDeletes,
    ownerId: `privacy-owner-${suffix}`,
    otherOwnerId: `privacy-other-${suffix}`,
    processor: new PrivacyOperationProcessor({
      storage,
      clock: new FixedServerClock(now),
      sessionGateway: sessions,
      authGateway: auth,
      receiptIdGenerator: new DeterministicReceiptIdGenerator(),
      operationIdGenerator: new OperationIdGenerator(),
      batchSize: 2,
    }),
  };
}

async function seedOwner(firestore, ownerId) {
  const writes = [
    [`users/${ownerId}`, { ownerId, schemaVersion: 1 }],
    [`users/${ownerId}/accounts/account-1`, { ownerId }],
    [`users/${ownerId}/categories/category-1`, { ownerId }],
    [`users/${ownerId}/transactions/transaction-1`, { ownerId }],
    [`users/${ownerId}/payables/payable-1`, { ownerId }],
    [`users/${ownerId}/receivables/receivable-1`, { ownerId }],
    [`users/${ownerId}/investmentPortfolios/portfolio-1`, { ownerId }],
    [`users/${ownerId}/investmentAssets/asset-1`, { ownerId }],
    [`users/${ownerId}/investmentOperations/operation-1`, { ownerId }],
    [`users/${ownerId}/investmentIncomeEvents/income-1`, { ownerId }],
    [`users/${ownerId}/assistantSettings/remote`, { consentVersion: 1 }],
    [`users/${ownerId}/entitlements/premium`, { ownerId }],
    [`system_admins/${ownerId}`, { ownerId }],
    [`_premiumClosedTestTesters/${ownerId}`, { ownerId }],
    [`_premiumClosedTestGrants/grant-${ownerId}`, { ownerId }],
    [`_marketQuoteDemands/${demandId(ownerId, 'asset-1')}`, { ticker: 'PETR4' }],
  ];
  const batch = firestore.batch();
  for (const [path, value] of writes) batch.set(firestore.doc(path), value);
  await batch.commit();
}

async function processUntilComplete(processor, ownerId, operationId) {
  for (let index = 0; index < 100; index += 1) {
    const result = await processor.process({ ownerId, operationId });
    if (result.state === 'completed') return result;
  }
  throw new Error('privacy_emulator_operation_did_not_complete');
}

const actor = (uid) => ({
  uid,
  authenticated: true,
  appCheckVerified: true,
  emailVerified: true,
  legalProfileVerified: true,
  authenticatedAt: now,
});

const demandId = (ownerId, assetId) => createHash('sha256')
  .update(`${ownerId}\u0000${assetId}`, 'utf8').digest('hex');
