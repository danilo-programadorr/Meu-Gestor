import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CLOSED_TEST_ACTIVATION_FUNCTION_OPTIONS,
  createFirebasePremiumCallables,
  PREMIUM_FUNCTION_OPTIONS,
} from '../src/firebase_callables.mjs';

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

function harness({ profileData = profile(), entitlementData = entitlement(), closedTestActivation = null } = {}) {
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
    closedTestActivation,
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

test('exports the three published bootstrap callables when closed-test activation is unavailable', () => {
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

test('closed test activation is callable only for the authenticated, verified and legal own UID', async () => {
  const activations = [];
  const h = harness({
    closedTestActivation: {
      activate: async ({ ownerId }) => {
        activations.push(ownerId);
        return { status: 'active', revision: 1, requiresServerRefresh: true };
      },
    },
  });
  assert.equal(h.calls.length, 4);
  assert.deepEqual(h.calls.slice(0, 3).map((call) => call.options), [
    PREMIUM_FUNCTION_OPTIONS,
    PREMIUM_FUNCTION_OPTIONS,
    PREMIUM_FUNCTION_OPTIONS,
  ]);
  assert.deepEqual(h.calls[3].options, CLOSED_TEST_ACTIVATION_FUNCTION_OPTIONS);
  assert.equal(h.calls[3].options.invoker, 'public');
  assert.equal(h.calls[3].options.enforceAppCheck, true);
  assert.equal(Object.hasOwn(PREMIUM_FUNCTION_OPTIONS, 'invoker'), false);
  assert.deepEqual(
    await h.callables.activateClosedTestPremium(request()),
    { status: 'active', revision: 1, requiresServerRefresh: true },
  );
  assert.deepEqual(activations, ['synthetic-user']);
  await rejectsCode(
    () => h.callables.activateClosedTestPremium(request({ app: null })),
    'failed-precondition',
  );
  await rejectsCode(
    () => h.callables.activateClosedTestPremium(request({ data: { ownerId: 'another-user' } })),
    'invalid-argument',
  );
});
