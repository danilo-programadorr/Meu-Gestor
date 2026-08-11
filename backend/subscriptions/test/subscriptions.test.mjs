import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DeterministicFakeGooglePlayGateway,
  InMemoryPurchaseTokenVault,
  InMemorySubscriptionStorage,
  PurchaseTokenFingerprinter,
  SubscriptionError,
  SubscriptionProcessor,
  applyAdministrativeGrant,
  mapGooglePlaySubscription,
  processAcknowledgementOutbox,
  processRtdn,
  revokeAdministrativeGrant,
  createObfuscatedExternalAccountId,
} from '../src/index.mjs';

const instant = (day, hour = 0) => `2026-08-${String(day).padStart(2, '0')}T${String(hour).padStart(2, '0')}:00:00.000Z`;
const fixedNow = () => new Date(instant(20, 12));
const packageName = 'dev.synthetic.app';
const productId = 'premium_monthly';
const account = 'synthetic-obfuscated-account';

function response(overrides = {}) {
  return {
    eventId: 'event-1', eventTime: instant(10), packageName, productId,
    environment: 'development', subscriptionState: 'ACTIVE', periodStart: instant(1),
    periodEnd: '2026-09-01T00:00:00.000Z', graceUntil: null, autoRenewEnabled: true,
    cancelledAt: null, expiredAt: null, revokedAt: null, refundedAt: null,
    acknowledgementState: 'PENDING', linkedPurchaseToken: null,
    obfuscatedExternalAccountId: account, ...overrides,
  };
}

function harness() {
  const gateway = new DeterministicFakeGooglePlayGateway();
  const storage = new InMemorySubscriptionStorage();
  const fingerprinter = new PurchaseTokenFingerprinter({ key: 'synthetic-test-key' });
  const tokenVault = new InMemoryPurchaseTokenVault();
  const accountObfuscator = (uid) => uid === 'synthetic-user-1' ? account : 'synthetic-obfuscated-account-2';
  const processor = new SubscriptionProcessor({ gateway, storage, fingerprinter, tokenVault, packageName, allowedProducts: [productId, 'premium_annual'], accountObfuscator, clock: fixedNow });
  return { gateway, storage, fingerprinter, tokenVault, processor };
}

function request(token = 'synthetic-token-1', overrides = {}) {
  return { actor: { uid: 'synthetic-user-1', authenticated: true, appCheckVerified: true }, environment: 'development', productId, purchaseToken: token, ...overrides };
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => error instanceof SubscriptionError && error.code === code);
}

const expected = () => ({ packageName, productId, environment: 'development', obfuscatedAccountId: account, allowedProducts: new Set([productId]) });

test('strict mapper accepts active state and exact fields', () => {
  const mapped = mapGooglePlaySubscription(response(), expected());
  assert.equal(mapped.status, 'active');
  assert.equal(mapped.planId, 'monthly');
  assert.equal(mapped.capabilities.length, 5);
});

test('strict mapper rejects extra, missing and unknown values', () => {
  assert.throws(() => mapGooglePlaySubscription({ ...response(), extra: true }, expected()));
  const missing = response(); delete missing.eventId;
  assert.throws(() => mapGooglePlaySubscription(missing, expected()));
  assert.throws(() => mapGooglePlaySubscription(response({ subscriptionState: 'NEW_UNKNOWN' }), expected()));
});

test('strict mapper denies identity mismatches', () => {
  for (const change of [{ packageName: 'other.app' }, { productId: 'other_monthly' }, { environment: 'production' }, { obfuscatedExternalAccountId: 'other' }]) {
    assert.throws(() => mapGooglePlaySubscription(response(change), expected()));
  }
});

test('strict mapper validates periods and lifecycle state', () => {
  for (const change of [
    { periodEnd: null },
    { subscriptionState: 'IN_GRACE_PERIOD', graceUntil: null },
    { subscriptionState: 'CANCELLED', autoRenewEnabled: true, cancelledAt: instant(9) },
    { subscriptionState: 'EXPIRED', autoRenewEnabled: false, expiredAt: null },
  ]) assert.throws(() => mapGooglePlaySubscription(response(change), expected()));
});

test('strict mapper rejects lifecycle timestamps after verification', () => {
  assert.throws(() => mapGooglePlaySubscription(response({
    subscriptionState: 'REVOKED',
    autoRenewEnabled: false,
    revokedAt: instant(11),
  }), expected()));
});

test('strict mapper covers every supported lifecycle state', () => {
  const cases = [
    ['PENDING', { periodStart: null, periodEnd: null, autoRenewEnabled: false }, 'pending'],
    ['TRIALING', {}, 'trialing'],
    ['ACTIVE', {}, 'active'],
    ['IN_GRACE_PERIOD', { graceUntil: '2026-09-05T00:00:00.000Z' }, 'gracePeriod'],
    ['ON_HOLD', { autoRenewEnabled: false }, 'accountHold'],
    ['PAUSED', { autoRenewEnabled: false }, 'paused'],
    ['CANCELLED', { autoRenewEnabled: false, cancelledAt: instant(9) }, 'cancelled'],
    ['EXPIRED', { eventTime: '2026-09-01T00:00:00.000Z', autoRenewEnabled: false, expiredAt: '2026-09-01T00:00:00.000Z' }, 'expired'],
    ['REVOKED', { autoRenewEnabled: false, revokedAt: instant(9) }, 'revoked'],
    ['REFUNDED', { autoRenewEnabled: false, refundedAt: instant(9) }, 'refunded'],
  ];
  for (const [subscriptionState, overrides, status] of cases) {
    assert.equal(mapGooglePlaySubscription(response({ subscriptionState, ...overrides }), expected()).status, status);
  }
});

test('processor persists projection without raw token', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response());
  const confirmation = await h.processor.process(request());
  assert.equal(confirmation.revision, 1);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).ownerId, 'synthetic-user-1');
  assert.doesNotMatch(JSON.stringify(await h.storage.snapshot()), /synthetic-token-1/);
});

test('processor denies unauthenticated actor and missing App Check', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response());
  await rejectsCode(() => h.processor.process(request('synthetic-token-1', { actor: { ...request().actor, authenticated: false } })), 'untrusted_subscription_actor');
  await rejectsCode(() => h.processor.process(request('synthetic-token-1', { actor: { ...request().actor, appCheckVerified: false } })), 'untrusted_subscription_actor');
});

test('processor rejects provider event beyond trusted server time', async () => {
  const h = harness();
  h.gateway.add('synthetic-token-1', response({ eventTime: '2026-08-21T00:00:00.000Z' }));
  await rejectsCode(() => h.processor.process(request()), 'subscription_verification_from_future');
});

test('same event and token is idempotent', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response());
  const first = await h.processor.process(request());
  assert.deepEqual(await h.processor.process(request()), first);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).revision, 1);
});

test('event id cannot be reused with another purchase', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); h.gateway.add('synthetic-token-2', response());
  await h.processor.process(request());
  await rejectsCode(() => h.processor.process(request('synthetic-token-2')), 'event_identity_conflict');
});

test('purchase cannot bind two users', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); await h.processor.process(request());
  h.gateway.add('synthetic-token-1', response({ eventId: 'event-2', obfuscatedExternalAccountId: 'synthetic-obfuscated-account-2' }));
  await rejectsCode(() => h.processor.process(request('synthetic-token-1', { actor: { ...request().actor, uid: 'synthetic-user-2' } })), 'purchase_binding_conflict');
});

test('linked purchase token preserves the same owner binding', async () => {
  const h = harness();
  h.gateway.add('synthetic-token-old', response({ eventId: 'event-old-token' }));
  await h.processor.process(request('synthetic-token-old'));
  h.gateway.add('synthetic-token-new', response({ eventId: 'event-linked', eventTime: instant(11), linkedPurchaseToken: 'synthetic-token-old' }));
  await h.processor.process(request('synthetic-token-new'));
  const oldFingerprint = h.fingerprinter.fingerprint('synthetic-token-old');
  const newFingerprint = h.fingerprinter.fingerprint('synthetic-token-new');
  assert.equal((await h.storage.binding(oldFingerprint)).ownerId, 'synthetic-user-1');
  assert.equal((await h.storage.binding(newFingerprint)).ownerId, 'synthetic-user-1');
});

test('linked token cannot transfer a purchase between users', async () => {
  const h = harness();
  h.gateway.add('synthetic-token-old', response({ eventId: 'event-old-token' }));
  await h.processor.process(request('synthetic-token-old'));
  h.gateway.add('synthetic-token-new', response({ eventId: 'event-linked', eventTime: instant(11), linkedPurchaseToken: 'synthetic-token-old', obfuscatedExternalAccountId: 'synthetic-obfuscated-account-2' }));
  await rejectsCode(() => h.processor.process(request('synthetic-token-new', { actor: { ...request().actor, uid: 'synthetic-user-2' } })), 'purchase_binding_conflict');
});

test('older event cannot regress entitlement', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); await h.processor.process(request());
  h.gateway.add('synthetic-token-1', response({ eventId: 'event-old', eventTime: instant(9), subscriptionState: 'PENDING', periodStart: null, periodEnd: null, autoRenewEnabled: false }));
  const result = await h.processor.process(request());
  assert.equal(result.ignoredAsOlder, true);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).status, 'active');
});

test('concurrent repetition creates one revision', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response());
  await Promise.all(Array.from({ length: 8 }, () => h.processor.process(request())));
  assert.equal((await h.storage.entitlement('synthetic-user-1')).revision, 1);
});

test('failure before commit does not persist success', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); h.storage.failBeforeCommit = true;
  await rejectsCode(() => h.processor.process(request()), 'storage_unavailable_before_commit');
  assert.equal(await h.storage.entitlement('synthetic-user-1'), null);
});

test('timeout after commit reconciles from event', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); h.storage.failAfterCommit = true;
  assert.equal((await h.processor.process(request())).revision, 1);
});

test('acknowledgement outbox is repeat-safe', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); await h.processor.process(request());
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 1 });
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 0 });
  assert.equal(h.gateway.acknowledgements.length, 1);
});

test('RTDN rejects environment mismatch and unknown binding', async () => {
  const h = harness();
  const expectedRtdn = { projectId: 'demo-project', packageName, environment: 'development', obfuscatedAccountIdFor: () => account };
  const note = { messageId: 'msg-1', projectId: 'wrong', packageName, environment: 'development', purchaseToken: 'synthetic-token-1' };
  await rejectsCode(() => processRtdn({ notification: note, expected: expectedRtdn, ...h }), 'rtdn_environment_mismatch');
  await rejectsCode(() => processRtdn({ notification: { ...note, projectId: 'demo-project' }, expected: expectedRtdn, ...h }), 'rtdn_purchase_not_bound');
});

test('RTDN re-queries gateway and is idempotent', async () => {
  const h = harness(); h.gateway.add('synthetic-token-1', response()); await h.processor.process(request());
  h.gateway.add('synthetic-token-1', response({ eventId: 'event-2', eventTime: instant(11) }));
  const expectedRtdn = { projectId: 'demo-project', packageName, environment: 'development', obfuscatedAccountIdFor: () => account };
  const notification = { messageId: 'msg-1', projectId: 'demo-project', packageName, environment: 'development', purchaseToken: 'synthetic-token-1' };
  const first = await processRtdn({ notification, expected: expectedRtdn, ...h });
  assert.deepEqual(await processRtdn({ notification, expected: expectedRtdn, ...h }), first);
  assert.equal(first.revision, 2);
});

function grant(overrides = {}) {
  return { grantId: 'grant-1', actorId: 'synthetic-user-1', ownerId: 'synthetic-user-1', reason: 'synthetic support test', environment: 'development', source: 'developmentGrant', planId: 'monthly', validFrom: instant(1), validUntil: '2026-09-01T00:00:00.000Z', capabilities: ['investmentsManual'], ...overrides };
}

test('development grant is scoped, audited and idempotent', async () => {
  const h = harness();
  const first = await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow });
  assert.deepEqual(await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow }), first);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).capabilities.length, 1);
});

test('development grant never targets production', async () => {
  const h = harness();
  await rejectsCode(() => applyAdministrativeGrant({ request: grant({ environment: 'production' }), storage: h.storage, clock: fixedNow }), 'development_grant_in_production');
});

test('grant denies cross-user and unknown capability', async () => {
  const h = harness();
  await rejectsCode(() => applyAdministrativeGrant({ request: grant({ ownerId: 'synthetic-user-2' }), storage: h.storage, clock: fixedNow }), 'grant_actor_denied');
  await rejectsCode(() => applyAdministrativeGrant({ request: grant({ capabilities: ['unknownCapability'] }), storage: h.storage, clock: fixedNow }), 'invalid_grant_scope');
});

test('grant revocation is terminal and idempotent', async () => {
  const h = harness(); await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow });
  const args = { grantId: 'grant-1', actorId: 'synthetic-user-1', ownerId: 'synthetic-user-1', reason: 'synthetic revocation', storage: h.storage, clock: fixedNow };
  const first = await revokeAdministrativeGrant(args);
  assert.deepEqual(await revokeAdministrativeGrant(args), first);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).status, 'revoked');
});

test('grant audit is sanitized and never retains actor, owner, reason or grant ID', async () => {
  const h = harness();
  await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow });
  const [audit] = await h.storage.audits();
  assert.deepEqual(Object.keys(audit).sort(), ['action', 'at', 'capabilityCount', 'environment', 'planId', 'revision', 'source']);
  assert.equal(JSON.stringify(audit).includes('synthetic-user-1'), false);
  assert.equal(JSON.stringify(audit).includes('synthetic support test'), false);
  assert.equal(JSON.stringify(audit).includes('grant-1'), false);
});

test('token fingerprint is deterministic and keyed', () => {
  const first = new PurchaseTokenFingerprinter({ key: 'synthetic-key-a' }).fingerprint('synthetic-token');
  const repeated = new PurchaseTokenFingerprinter({ key: 'synthetic-key-a' }).fingerprint('synthetic-token');
  const other = new PurchaseTokenFingerprinter({ key: 'synthetic-key-b' }).fingerprint('synthetic-token');
  assert.equal(first, repeated);
  assert.notEqual(first, other);
  assert.doesNotMatch(first, /synthetic-token/);
});

test('external account identifier is irreversibly derived by backend', () => {
  const first = createObfuscatedExternalAccountId({ uid: 'synthetic-user-1', key: 'synthetic-account-key' });
  const repeated = createObfuscatedExternalAccountId({ uid: 'synthetic-user-1', key: 'synthetic-account-key' });
  const other = createObfuscatedExternalAccountId({ uid: 'synthetic-user-2', key: 'synthetic-account-key' });
  assert.equal(first, repeated);
  assert.notEqual(first, other);
  assert.doesNotMatch(first, /synthetic-user-1/);
});
