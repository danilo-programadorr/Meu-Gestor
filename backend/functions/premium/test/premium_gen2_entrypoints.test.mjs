import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DeterministicFakeGooglePlayDeveloperApiGateway,
  InMemoryPurchaseTokenVault,
  InMemorySubscriptionStorage,
  PurchaseTokenFingerprinter,
  SubscriptionError,
  SubscriptionProcessor,
} from '../../../subscriptions/src/index.mjs';
import { createPremiumGen2Entrypoints } from '../src/gen2_entrypoints.mjs';
import { createPremiumFunctionsRuntime } from '../src/premium_runtime.mjs';
import {
  googlePlaySubscriptionResponse,
  instant,
  rtdnNotification,
  syntheticAccountId,
  syntheticPackageName,
  syntheticProjectId,
} from '../../../subscriptions/test/fixtures/google_play_subscription.mjs';

const fixedNow = () => new Date(instant(20, 12));
const closedTestWindow = Object.freeze({
  environment: 'development',
  track: 'closed',
  startsAt: instant(6),
  expiresAt: instant(21),
});

function harness() {
  const storage = new InMemorySubscriptionStorage();
  const gateway = new DeterministicFakeGooglePlayDeveloperApiGateway();
  const fingerprinter = new PurchaseTokenFingerprinter({ key: 'synthetic-functions-key' });
  const processor = new SubscriptionProcessor({
    gateway,
    storage,
    fingerprinter,
    tokenVault: new InMemoryPurchaseTokenVault(),
    packageName: syntheticPackageName,
    environmentConfiguration: { environment: 'development', projectId: syntheticProjectId },
    catalog: {
      subscriptionId: 'meu_gestor_premium',
      monthlyBasePlanId: 'mensal',
      annualBasePlanId: 'anual',
      monthlyTrialOfferId: 'teste-3d',
      monthlyTrialDurationHours: 72,
    },
    accountObfuscator: () => syntheticAccountId,
    clock: fixedNow,
  });
  const runtime = createPremiumFunctionsRuntime({
    processor,
    storage,
    fingerprinter,
    closedTestWindow,
    authorizedClosedTestOwnerIds: new Set(['synthetic-user-1']),
    clock: fixedNow,
    assertAdministrativeIdentity: async (identity) => {
      if (identity !== 'synthetic-administrator') throw new SubscriptionError('administrative_identity_denied', 'Negado.');
    },
  });
  return { gateway, storage, runtime };
}

function callable(data = {}) {
  return { auth: { uid: 'synthetic-user-1' }, appCheckVerified: true, data };
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => error instanceof SubscriptionError && error.code === code);
}

test('verify and restore reuse the processor and require App Check', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', googlePlaySubscriptionResponse());
  const verified = await h.runtime.verifyGooglePlayPurchase(callable({ purchaseToken: 'synthetic-purchase-token-1' }));
  const restored = await h.runtime.restoreGooglePlayPurchase(callable({ purchaseToken: 'synthetic-purchase-token-1' }));
  assert.equal(verified.status, 'active');
  assert.deepEqual(restored, verified);
  await rejectsCode(
    () => h.runtime.verifyGooglePlayPurchase({ ...callable({ purchaseToken: 'synthetic-purchase-token-1' }), appCheckVerified: false }),
    'untrusted_premium_callable',
  );
});

test('confirmed entitlement is own-only and removes backend metadata', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', googlePlaySubscriptionResponse());
  await h.runtime.verifyGooglePlayPurchase(callable({ purchaseToken: 'synthetic-purchase-token-1' }));
  const response = await h.runtime.getConfirmedEntitlement(callable());
  assert.equal(response.entitlement.ownerId, 'synthetic-user-1');
  assert.equal(Object.hasOwn(response.entitlement, 'projectId'), false);
  assert.equal(Object.hasOwn(response.entitlement, 'packageName'), false);
  assert.equal(Object.hasOwn(response.entitlement, 'purchaseCycleFingerprint'), false);
});

test('RTDN accepts only trusted perimeter signal and reuses authoritative query', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', googlePlaySubscriptionResponse());
  await h.runtime.verifyGooglePlayPurchase(callable({ purchaseToken: 'synthetic-purchase-token-1' }));
  await rejectsCode(
    () => h.runtime.processRtdnSignal({ notification: rtdnNotification(), rtdnVerified: false }),
    'untrusted_rtdn_signal',
  );
  const confirmation = await h.runtime.processRtdnSignal({ notification: rtdnNotification(), rtdnVerified: true });
  assert.equal(confirmation.status, 'active');
  assert.equal(h.gateway.queries.length, 2);
});

test('closed test administration is not callable and denies production-shaped input', async () => {
  const h = harness();
  await rejectsCode(
    () => h.runtime.issueClosedTestGrant({ administrativeIdentity: 'untrusted', data: { grantId: 'closed-1', ownerId: 'synthetic-user-1', track: 'closed' } }),
    'administrative_identity_denied',
  );
  const confirmation = await h.runtime.issueClosedTestGrant({
    administrativeIdentity: 'synthetic-administrator',
    data: { grantId: 'closed-1', ownerId: 'synthetic-user-1', track: 'closed' },
  });
  assert.equal(confirmation.status, 'active');
  assert.equal((await h.storage.entitlement('synthetic-user-1')).environment, 'development');
});

test('Gen 2 factories scope App Check to new callables only', () => {
  const h = harness();
  const calls = [];
  const entries = createPremiumGen2Entrypoints({
    onCall: (options, handler) => { calls.push({ kind: 'call', options, handler }); return { options, handler }; },
    onRequest: (options, handler) => { calls.push({ kind: 'request', options, handler }); return { options, handler }; },
    runtime: h.runtime,
    verifyRtdnRequest: async () => rtdnNotification(),
    verifyAdministrativeRequest: async () => ({
      administrativeIdentity: 'synthetic-administrator',
      data: { grantId: 'closed-entrypoint', ownerId: 'synthetic-user-1', track: 'closed' },
    }),
  });
  assert.equal(calls.filter((call) => call.kind === 'call').length, 3);
  assert.equal(calls.filter((call) => call.kind === 'request').length, 3);
  assert.equal(entries.verifyGooglePlayPurchase.options.enforceAppCheck, true);
  assert.equal(Object.hasOwn(entries.receiveGooglePlayRtdn.options, 'enforceAppCheck'), false);
});

test('Gen 2 HTTP handlers accept only identities produced by perimeter verifiers', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', googlePlaySubscriptionResponse());
  await h.runtime.verifyGooglePlayPurchase(callable({ purchaseToken: 'synthetic-purchase-token-1' }));
  const entries = createPremiumGen2Entrypoints({
    onCall: (_options, handler) => handler,
    onRequest: (_options, handler) => handler,
    runtime: h.runtime,
    verifyRtdnRequest: async () => rtdnNotification(),
    verifyAdministrativeRequest: async () => ({
      administrativeIdentity: 'synthetic-administrator',
      data: { grantId: 'closed-entrypoint', ownerId: 'synthetic-user-1', track: 'closed' },
    }),
  });
  assert.equal((await entries.receiveGooglePlayRtdn({ body: { rtdnVerified: false } })).status, 'active');
  assert.equal((await entries.administerClosedTestGrant({ body: {} })).status, 'active');
});
