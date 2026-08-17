import assert from 'node:assert/strict';
import test from 'node:test';
import { createFirebasePremiumCallables, PREMIUM_FUNCTION_OPTIONS } from '../src/firebase_callables.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function timestamp() {
  return { toDate: () => new Date('2026-08-20T00:00:00.000Z') };
}

function profile(uid = 'synthetic-user') {
  return {
    ownerId: uid,
    displayName: 'Usuário Sintético',
    locale: 'pt-BR',
    currencyCode: 'BRL',
    timeZone: 'America/Sao_Paulo',
    emailVerifiedSnapshot: true,
    termsVersionAccepted: 'terms-dev-1.0.0',
    termsAcceptedAt: timestamp(),
    privacyVersionAccepted: 'privacy-dev-1.0.0',
    privacyAcceptedAt: timestamp(),
    aiConsentEnabled: false,
    aiConsentUpdatedAt: timestamp(),
    analyticsConsentEnabled: false,
    analyticsConsentUpdatedAt: timestamp(),
    createdAt: timestamp(),
    updatedAt: timestamp(),
    schemaVersion: 1,
  };
}

function entitlement(uid = 'synthetic-user') {
  return {
    ownerId: uid,
    planId: 'monthly',
    status: 'active',
    source: 'googlePlay',
    environment: 'development',
    capabilities: ['investmentsManual'],
    startedAt: timestamp(),
    currentPeriodStart: timestamp(),
    currentPeriodEnd: timestamp(),
    graceUntil: null,
    cancelAtPeriodEnd: false,
    cancelledAt: null,
    expiredAt: null,
    revokedAt: null,
    refundedAt: null,
    lastVerifiedAt: timestamp(),
    revision: 1,
    schemaVersion: 1,
    createdAt: timestamp(),
    updatedAt: timestamp(),
  };
}

function harness({ profileData = profile(), entitlementData = entitlement() } = {}) {
  const documents = new Map([
    ['users/synthetic-user', profileData],
    ['users/synthetic-user/entitlements/premium', entitlementData],
  ]);
  const calls = [];
  const firestore = {
    doc: (path) => ({
      get: async () => ({
        exists: documents.has(path),
        data: () => documents.get(path),
      }),
    }),
  };
  const callables = createFirebasePremiumCallables({
    onCall: (options, handler) => { calls.push({ options, handler }); return handler; },
    HttpsError: FakeHttpsError,
    firestore,
  });
  return { callables, calls };
}

function request(overrides = {}) {
  return {
    auth: { uid: 'synthetic-user', token: { email_verified: true } },
    app: { appId: 'synthetic-app' },
    data: {},
    ...overrides,
  };
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => error instanceof FakeHttpsError && error.code === code);
}

test('exports three constrained Gen 2 callables in southamerica-east1', () => {
  const h = harness();
  assert.equal(h.calls.length, 3);
  for (const call of h.calls) {
    assert.deepEqual(call.options, PREMIUM_FUNCTION_OPTIONS);
  }
  assert.equal(PREMIUM_FUNCTION_OPTIONS.region, 'southamerica-east1');
  assert.equal(PREMIUM_FUNCTION_OPTIONS.maxInstances, 1);
  assert.equal(PREMIUM_FUNCTION_OPTIONS.concurrency, 1);
  assert.equal(PREMIUM_FUNCTION_OPTIONS.enforceAppCheck, true);
  assert.equal(PREMIUM_FUNCTION_OPTIONS.serviceAccount.name, 'PREMIUM_RUNTIME_SERVICE_ACCOUNT');
});

test('confirmed entitlement requires own authenticated, verified and legal caller', async () => {
  const h = harness();
  const result = await h.callables.getConfirmedEntitlement(request());
  assert.equal(result.entitlement.ownerId, 'synthetic-user');
  assert.equal(result.entitlement.startedAt, '2026-08-20T00:00:00.000Z');
  await rejectsCode(() => h.callables.getConfirmedEntitlement(request({ auth: null })), 'unauthenticated');
  await rejectsCode(() => h.callables.getConfirmedEntitlement(request({ auth: { uid: 'synthetic-user', token: {} } })), 'permission-denied');
  await rejectsCode(() => h.callables.getConfirmedEntitlement(request({ app: null })), 'failed-precondition');
});

test('invalid profile or cross-UID entitlement fails closed', async () => {
  const invalidProfile = { ...profile(), termsVersionAccepted: 'obsolete' };
  await rejectsCode(
    () => harness({ profileData: invalidProfile }).callables.getConfirmedEntitlement(request()),
    'permission-denied',
  );
  await rejectsCode(
    () => harness({ entitlementData: entitlement('another-user') }).callables.getConfirmedEntitlement(request()),
    'internal',
  );
});

test('purchase and restore reject before any write while E-3B is unavailable', async () => {
  const h = harness();
  await rejectsCode(() => h.callables.verifyGooglePlayPurchase(request()), 'failed-precondition');
  await rejectsCode(() => h.callables.restoreGooglePlayPurchase(request()), 'failed-precondition');
  await rejectsCode(
    () => h.callables.verifyGooglePlayPurchase(request({ data: { purchaseToken: 'synthetic' } })),
    'invalid-argument',
  );
});
