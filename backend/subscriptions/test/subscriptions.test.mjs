import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DeterministicFakeGooglePlayDeveloperApiGateway,
  InMemoryPurchaseTokenVault,
  InMemorySubscriptionStorage,
  PREMIUM_GOOGLE_PLAY_CATALOG,
  PurchaseTokenFingerprinter,
  SubscriptionError,
  SubscriptionProcessor,
  assertSubscriptionTransition,
  applyAdministrativeGrant,
  issueClosedTestGrant,
  expireClosedTestGrants,
  createObfuscatedExternalAccountId,
  mapGooglePlaySubscription,
  processAcknowledgementOutbox,
  processRtdn,
  resolvePremiumGooglePlayCatalog,
  revokeAdministrativeGrant,
} from '../src/index.mjs';
import {
  googlePlaySubscriptionResponse,
  instant,
  rtdnNotification,
  syntheticAccountId,
  syntheticPackageName,
  syntheticProjectId,
} from './fixtures/google_play_subscription.mjs';

const fixedNow = () => new Date(instant(20, 12));
const packageName = syntheticPackageName;
const environment = 'development';
const account = syntheticAccountId;
const catalog = PREMIUM_GOOGLE_PLAY_CATALOG;

function response(overrides = {}) {
  return googlePlaySubscriptionResponse(overrides);
}

class TrackingPurchaseTokenVault extends InMemoryPurchaseTokenVault {
  storedReferences = [];

  async store(fingerprint, token) {
    const reference = await super.store(fingerprint, token);
    this.storedReferences.push(reference);
    return reference;
  }
}

class DeferredDuplicateFailureStorage extends InMemorySubscriptionStorage {
  #firstTransactionEntered;
  #releaseFirstTransaction;
  #transactionCount = 0;

  constructor() {
    super();
    this.firstTransactionEntered = new Promise((resolve) => {
      this.#firstTransactionEntered = resolve;
    });
    this.releaseFirstTransaction = new Promise((resolve) => {
      this.#releaseFirstTransaction = resolve;
    });
  }

  allowFirstTransactionCommit() {
    this.#releaseFirstTransaction();
  }

  async transaction(operation) {
    const transactionNumber = this.#transactionCount;
    this.#transactionCount += 1;
    return super.transaction(async (state) => {
      if (transactionNumber === 0) {
        this.#firstTransactionEntered();
        await this.releaseFirstTransaction;
      }
      const result = await operation(state);
      if (transactionNumber === 1) {
        throw new SubscriptionError('storage_unavailable_before_commit', 'Falha sintética antes da confirmação.');
      }
      return result;
    });
  }
}

class DeferredAcknowledgementGateway extends DeterministicFakeGooglePlayDeveloperApiGateway {
  #acknowledgementEntered;
  #releaseAcknowledgement;

  constructor() {
    super();
    this.acknowledgementEntered = new Promise((resolve) => {
      this.#acknowledgementEntered = resolve;
    });
    this.releaseAcknowledgement = new Promise((resolve) => {
      this.#releaseAcknowledgement = resolve;
    });
  }

  allowAcknowledgement() {
    this.#releaseAcknowledgement();
  }

  async acknowledge(requestValue) {
    this.#acknowledgementEntered();
    await this.releaseAcknowledgement;
    return super.acknowledge(requestValue);
  }
}

function harness({
  configuredEnvironment = environment,
  configuredProjectId = syntheticProjectId,
  configuredPackageName = packageName,
  storage = new InMemorySubscriptionStorage(),
  gateway = new DeterministicFakeGooglePlayDeveloperApiGateway(),
  tokenVault = new TrackingPurchaseTokenVault(),
} = {}) {
  const fingerprinter = new PurchaseTokenFingerprinter({ key: 'synthetic-test-key' });
  const accountObfuscator = (uid) => (
    uid === 'synthetic-user-1' ? account : 'synthetic-obfuscated-account-2'
  );
  const processor = new SubscriptionProcessor({
    gateway,
    storage,
    fingerprinter,
    tokenVault,
    packageName: configuredPackageName,
    environmentConfiguration: {
      environment: configuredEnvironment,
      projectId: configuredProjectId,
    },
    catalog,
    accountObfuscator,
    clock: fixedNow,
  });
  return { gateway, storage, fingerprinter, tokenVault, processor, clock: fixedNow };
}

function request(token = 'synthetic-purchase-token-1', overrides = {}) {
  return {
    actor: { uid: 'synthetic-user-1', authenticated: true, appCheckVerified: true },
    purchaseToken: token,
    ...overrides,
  };
}

function expected(overrides = {}) {
  return {
    packageName,
    environment,
    obfuscatedAccountId: account,
    catalog,
    ...overrides,
  };
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => error instanceof SubscriptionError && error.code === code);
}

class TransactionTrackingStorage extends InMemorySubscriptionStorage {
  #activeTransactions = 0;

  get activeTransactions() {
    return this.#activeTransactions;
  }

  async transaction(operation) {
    return super.transaction(async (state) => {
      this.#activeTransactions += 1;
      try {
        return await operation(state);
      } finally {
        this.#activeTransactions -= 1;
      }
    });
  }
}

test('approved catalog has one subscription, two base plans and one monthly trial offer', () => {
  assert.deepEqual(catalog, {
    subscriptionId: 'meu_gestor_premium',
    monthlyBasePlanId: 'mensal',
    annualBasePlanId: 'anual',
    monthlyTrialOfferId: 'teste-3d',
    monthlyTrialDurationHours: 72,
  });
  assert.equal(resolvePremiumGooglePlayCatalog({ ...catalog }), catalog);
});

test('catalog rejects a second product, alternative base plan or annual trial', () => {
  for (const configuration of [
    { ...catalog, subscriptionId: 'other_premium' },
    { ...catalog, monthlyBasePlanId: 'monthly' },
    { ...catalog, annualBasePlanId: 'yearly' },
    { ...catalog, monthlyTrialOfferId: 'annual-trial' },
    { ...catalog, monthlyTrialDurationHours: 24 },
  ]) {
    assert.throws(
      () => resolvePremiumGooglePlayCatalog(configuration),
      (error) => error instanceof SubscriptionError && error.code === 'unsupported_google_play_catalog',
    );
  }
});

test('strict mapper accepts an approved monthly base plan without hardcoded price', () => {
  const mapped = mapGooglePlaySubscription(response(), expected());
  assert.equal(mapped.status, 'active');
  assert.equal(mapped.subscriptionId, 'meu_gestor_premium');
  assert.equal(mapped.basePlanId, 'mensal');
  assert.equal(mapped.offerId, null);
  assert.equal(mapped.planId, 'monthly');
  assert.equal(mapped.environment, 'development');
  assert.equal(mapped.capabilities.length, 5);
  assert.equal(Object.hasOwn(mapped, 'localizedPrice'), false);
});

test('strict mapper accepts annual and the trial offer only on monthly', () => {
  const annual = mapGooglePlaySubscription(response({ basePlanId: 'anual' }), expected());
  const trial = mapGooglePlaySubscription(response({
    subscriptionState: 'TRIALING',
    offerId: 'teste-3d',
    periodEnd: instant(4),
  }), expected());
  assert.equal(annual.planId, 'annual');
  assert.equal(annual.offerId, null);
  assert.equal(trial.planId, 'monthly');
  assert.equal(trial.offerId, 'teste-3d');
});

test('strict mapper accepts a verified active subscription retaining the monthly trial offer', () => {
  const activeAfterTrial = mapGooglePlaySubscription(response({
    subscriptionState: 'ACTIVE',
    offerId: 'teste-3d',
  }), expected());
  assert.equal(activeAfterTrial.status, 'active');
  assert.equal(activeAfterTrial.offerId, 'teste-3d');
});

test('strict mapper accepts trialing only with the approved monthly three-day offer', () => {
  for (const change of [
    { subscriptionState: 'TRIALING', offerId: null, periodEnd: instant(4) },
    { subscriptionState: 'TRIALING', basePlanId: 'anual', offerId: 'teste-3d', periodEnd: instant(4) },
  ]) {
    assert.throws(() => mapGooglePlaySubscription(response(change), expected()));
  }
});

test('strict mapper rejects extra, missing, price and unknown values', () => {
  assert.throws(() => mapGooglePlaySubscription({ ...response(), extra: true }, expected()));
  assert.throws(() => mapGooglePlaySubscription({ ...response(), localizedPrice: 'synthetic' }, expected()));
  const missing = response();
  delete missing.eventId;
  assert.throws(() => mapGooglePlaySubscription(missing, expected()));
  assert.throws(() => mapGooglePlaySubscription(response({ subscriptionState: 'NEW_UNKNOWN' }), expected()));
});

test('strict mapper denies other subscription IDs, base plans and offers', () => {
  for (const change of [
    { subscriptionId: 'other_premium' },
    { basePlanId: 'weekly' },
    { basePlanId: 'anual', offerId: 'teste-3d' },
    { basePlanId: 'mensal', offerId: 'other-offer' },
  ]) {
    assert.throws(() => mapGooglePlaySubscription(response(change), expected()));
  }
});

test('strict mapper rejects a trial with a duration other than 72 hours', () => {
  assert.throws(() => mapGooglePlaySubscription(response({
    subscriptionState: 'TRIALING',
    offerId: 'teste-3d',
    periodEnd: instant(3),
  }), expected()));
});

test('strict mapper denies identity mismatch and a provider-supplied environment', () => {
  for (const change of [
    { packageName: 'com.example.other' },
    { obfuscatedExternalAccountId: 'other' },
    { environment: 'production' },
  ]) {
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

test('strict mapper preserves a scheduled cancellation when the subscription expires', () => {
  const mapped = mapGooglePlaySubscription(response({
    subscriptionState: 'EXPIRED',
    eventTime: '2026-09-01T00:00:00.000Z',
    autoRenewEnabled: false,
    cancelledAt: instant(9),
    expiredAt: '2026-09-01T00:00:00.000Z',
  }), expected());
  assert.equal(mapped.status, 'expired');
  assert.equal(mapped.cancelledAt, instant(9));
  assert.equal(mapped.cancelAtPeriodEnd, true);
});

test('strict mapper covers every supported lifecycle state', () => {
  const cases = [
    ['PENDING', { periodStart: null, periodEnd: null, autoRenewEnabled: false }, 'pending'],
    ['TRIALING', { offerId: 'teste-3d', periodEnd: instant(4) }, 'trialing'],
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

test('processor derives environment and catalog locally, without client plan selection', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await rejectsCode(
    () => h.processor.process({ ...request(), environment: 'production' }),
    'invalid_subscription_request',
  );
  await rejectsCode(
    () => h.processor.process({ ...request(), subscriptionId: 'other_premium' }),
    'invalid_subscription_request',
  );
  const confirmation = await h.processor.process(request());
  assert.equal(confirmation.revision, 1);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).environment, 'development');
  assert.deepEqual(h.gateway.queries, [{ packageName }]);
});

test('processor persists projection and outbox without raw tokens', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({ linkedPurchaseToken: 'synthetic-linked-token' }));
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const snapshot = await h.storage.snapshot();
  const serialized = JSON.stringify(snapshot);
  assert.doesNotMatch(serialized, /synthetic-purchase-token-1/);
  assert.doesNotMatch(serialized, /synthetic-linked-token/);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).ownerId, 'synthetic-user-1');
  assert.equal(snapshot.bindings.get(fingerprint).projectId, syntheticProjectId);
  assert.equal(snapshot.bindings.get(fingerprint).packageName, packageName);
});

test('processor does not retain a token or reference already acknowledged by Play', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    acknowledgementState: 'ACKNOWLEDGED',
  }));
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const snapshot = await h.storage.snapshot();
  assert.equal(snapshot.acknowledgementOutbox.size, 0);
  assert.equal(Object.hasOwn(snapshot.bindings.get(fingerprint), 'tokenReference'), false);
  assert.doesNotMatch(JSON.stringify(snapshot), /memory-vault:/);
});

test('pending subscription never reaches the acknowledgement outbox', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    subscriptionState: 'PENDING',
    periodStart: null,
    periodEnd: null,
    autoRenewEnabled: false,
  }));
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const snapshot = await h.storage.snapshot();
  assert.equal(h.tokenVault.storedReferences.length, 0);
  assert.equal(Object.hasOwn(snapshot.bindings.get(fingerprint), 'tokenReference'), false);
  assert.equal(snapshot.acknowledgementOutbox.size, 0);
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 0 });
  assert.deepEqual(h.gateway.acknowledgements, []);
});

test('processor persists annual plan and cancellation from verified store data', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    basePlanId: 'anual',
    subscriptionState: 'CANCELLED',
    autoRenewEnabled: false,
    cancelledAt: instant(9),
  }));
  await h.processor.process(request());
  const entitlement = await h.storage.entitlement('synthetic-user-1');
  assert.equal(entitlement.planId, 'annual');
  assert.equal(entitlement.status, 'cancelled');
  assert.equal(entitlement.cancelAtPeriodEnd, true);
});

test('processor allows trialing to become active when the verified offer remains present', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    subscriptionState: 'TRIALING',
    offerId: 'teste-3d',
    periodEnd: instant(4),
  }));
  await h.processor.process(request());
  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-active-after-trial',
    eventTime: instant(11),
    subscriptionState: 'ACTIVE',
    offerId: 'teste-3d',
    periodStart: instant(4),
    periodEnd: '2026-09-04T00:00:00.000Z',
  }));
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  assert.equal((await h.storage.entitlement('synthetic-user-1')).status, 'active');
  assert.equal((await h.storage.binding(fingerprint)).offerId, 'teste-3d');
});

test('processor denies unauthenticated actor and missing App Check', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await rejectsCode(() => h.processor.process(request('synthetic-purchase-token-1', {
    actor: { ...request().actor, authenticated: false },
  })), 'untrusted_subscription_actor');
  await rejectsCode(() => h.processor.process(request('synthetic-purchase-token-1', {
    actor: { ...request().actor, appCheckVerified: false },
  })), 'untrusted_subscription_actor');
});

test('processor fails closed when the future Play Developer API adapter is unavailable', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  h.gateway.available = false;
  await rejectsCode(() => h.processor.process(request()), 'google_play_service_unavailable');
  assert.equal(await h.storage.entitlement('synthetic-user-1'), null);
});

test('processor rejects provider event beyond trusted server time', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({ eventTime: '2026-08-21T00:00:00.000Z' }));
  await rejectsCode(() => h.processor.process(request()), 'subscription_verification_from_future');
});

test('same event and token is idempotent', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  const first = await h.processor.process(request());
  assert.deepEqual(await h.processor.process(request()), first);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).revision, 1);
});

test('event ID cannot be reused with another purchase', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  h.gateway.add('synthetic-purchase-token-2', response());
  await h.processor.process(request());
  await rejectsCode(() => h.processor.process(request('synthetic-purchase-token-2')), 'event_identity_conflict');
  const [firstReference, rejectedReference] = h.tokenVault.storedReferences;
  assert.equal(
    await h.tokenVault.retrieve(firstReference),
    'synthetic-purchase-token-1',
  );
  await rejectsCode(
    () => h.tokenVault.retrieve(rejectedReference),
    'purchase_token_not_available',
  );
});

test('purchase cannot bind two users', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-2',
    obfuscatedExternalAccountId: 'synthetic-obfuscated-account-2',
  }));
  await rejectsCode(() => h.processor.process(request('synthetic-purchase-token-1', {
    actor: { ...request().actor, uid: 'synthetic-user-2' },
  })), 'purchase_binding_conflict');
});

test('linked purchase token preserves the same owner binding', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-old', response({ eventId: 'synthetic-event-old-token' }));
  await h.processor.process(request('synthetic-purchase-token-old'));
  h.gateway.add('synthetic-purchase-token-new', response({
    eventId: 'synthetic-event-linked',
    eventTime: instant(11),
    linkedPurchaseToken: 'synthetic-purchase-token-old',
    periodStart: instant(10),
    periodEnd: '2026-10-01T00:00:00.000Z',
  }));
  await h.processor.process(request('synthetic-purchase-token-new'));
  const oldFingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-old');
  const newFingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-new');
  assert.equal((await h.storage.binding(oldFingerprint)).ownerId, 'synthetic-user-1');
  assert.equal((await h.storage.binding(newFingerprint)).ownerId, 'synthetic-user-1');
});

test('linked token cannot transfer a purchase between users', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-old', response({ eventId: 'synthetic-event-old-token' }));
  await h.processor.process(request('synthetic-purchase-token-old'));
  h.gateway.add('synthetic-purchase-token-new', response({
    eventId: 'synthetic-event-linked',
    eventTime: instant(11),
    linkedPurchaseToken: 'synthetic-purchase-token-old',
    obfuscatedExternalAccountId: 'synthetic-obfuscated-account-2',
  }));
  await rejectsCode(() => h.processor.process(request('synthetic-purchase-token-new', {
    actor: { ...request().actor, uid: 'synthetic-user-2' },
  })), 'purchase_binding_conflict');
});

test('older event cannot regress entitlement', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-old',
    eventTime: instant(9),
    subscriptionState: 'PENDING',
    periodStart: null,
    periodEnd: null,
    autoRenewEnabled: false,
  }));
  const result = await h.processor.process(request());
  assert.equal(result.ignoredAsOlder, true);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).status, 'active');
});

test('a later active event cannot overwrite revoked or refunded entitlement', async () => {
  for (const [subscriptionState, terminalField] of [
    ['REVOKED', 'revokedAt'],
    ['REFUNDED', 'refundedAt'],
  ]) {
    const h = harness();
    h.gateway.add('synthetic-purchase-token-1', response({
      subscriptionState,
      autoRenewEnabled: false,
      [terminalField]: instant(9),
    }));
    await h.processor.process(request());
    h.gateway.add('synthetic-purchase-token-1', response({
      eventId: `synthetic-event-active-after-${subscriptionState.toLowerCase()}`,
      eventTime: instant(11),
      subscriptionState: 'ACTIVE',
    }));
    await rejectsCode(
      () => h.processor.process(request()),
      'subscription_terminal_transition_denied',
    );
    const entitlement = await h.storage.entitlement('synthetic-user-1');
    assert.equal(entitlement.status, subscriptionState.toLowerCase());
    assert.equal(entitlement.revision, 1);
    const [initialReference, rejectedReference] = h.tokenVault.storedReferences;
    assert.equal(
      await h.tokenVault.retrieve(initialReference),
      'synthetic-purchase-token-1',
    );
    await rejectsCode(
      () => h.tokenVault.retrieve(rejectedReference),
      'purchase_token_not_available',
    );
  }
});

test('a verified new purchase cycle can replace a revoked or refunded entitlement', async () => {
  for (const [subscriptionState, terminalField] of [
    ['REVOKED', 'revokedAt'],
    ['REFUNDED', 'refundedAt'],
  ]) {
    const h = harness();
    h.gateway.add('synthetic-purchase-token-1', response({
      subscriptionState,
      autoRenewEnabled: false,
      [terminalField]: instant(9),
    }));
    await h.processor.process(request());
    h.gateway.add('synthetic-purchase-token-2', response({
      eventId: `synthetic-event-new-cycle-after-${subscriptionState.toLowerCase()}`,
      eventTime: instant(11),
      periodStart: instant(10),
    }));
    const confirmation = await h.processor.process(request('synthetic-purchase-token-2'));
    const entitlement = await h.storage.entitlement('synthetic-user-1');
    assert.equal(confirmation.revision, 2);
    assert.equal(entitlement.status, 'active');
    assert.equal(
      entitlement.purchaseCycleFingerprint,
      h.fingerprinter.fingerprint('synthetic-purchase-token-2'),
    );
  }
});

test('terminal entitlement denies an invalid new purchase cycle before its terminal instant', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    subscriptionState: 'REVOKED',
    autoRenewEnabled: false,
    revokedAt: instant(9),
  }));
  await h.processor.process(request());
  h.gateway.add('synthetic-purchase-token-2', response({
    eventId: 'synthetic-event-invalid-new-cycle',
    eventTime: instant(11),
    periodStart: instant(8),
  }));
  await rejectsCode(
    () => h.processor.process(request('synthetic-purchase-token-2')),
    'subscription_new_cycle_period_denied',
  );
});

test('expired entitlement requires a non-overlapping new purchase cycle', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response({
    subscriptionState: 'EXPIRED',
    eventTime: instant(10),
    periodEnd: instant(10),
    autoRenewEnabled: false,
    expiredAt: instant(10),
  }));
  await h.processor.process(request());

  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-expired-same-cycle',
    eventTime: instant(11),
    periodStart: instant(10),
  }));
  await rejectsCode(
    () => h.processor.process(request()),
    'subscription_expired_cycle_denied',
  );

  h.gateway.add('synthetic-purchase-token-2', response({
    eventId: 'synthetic-event-expired-overlap',
    eventTime: instant(11),
    periodStart: instant(9),
  }));
  await rejectsCode(
    () => h.processor.process(request('synthetic-purchase-token-2')),
    'subscription_new_cycle_period_denied',
  );

  h.gateway.add('synthetic-purchase-token-2', response({
    eventId: 'synthetic-event-expired-new-cycle',
    eventTime: instant(11),
    periodStart: instant(10),
    linkedPurchaseToken: 'synthetic-purchase-token-1',
  }));
  assert.equal(
    (await h.processor.process(request('synthetic-purchase-token-2'))).revision,
    2,
  );
});

test('processor denies period regressions and accepts only a real renewal', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  for (const [eventId, overrides] of [
    ['synthetic-event-shorter-period', {
      eventTime: instant(11),
      periodEnd: '2026-08-31T00:00:00.000Z',
    }],
    ['synthetic-event-earlier-start', {
      eventTime: instant(11),
      periodStart: '2026-07-31T00:00:00.000Z',
      periodEnd: '2026-10-01T00:00:00.000Z',
    }],
    ['synthetic-event-same-period', {
      eventTime: instant(11),
    }],
  ]) {
    h.gateway.add('synthetic-purchase-token-1', response({ eventId, ...overrides }));
    await rejectsCode(
      () => h.processor.process(request()),
      'subscription_period_regression',
    );
  }
  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-renewal',
    eventTime: instant(11),
    periodEnd: '2026-10-01T00:00:00.000Z',
  }));
  assert.equal((await h.processor.process(request())).revision, 2);
});

test('processor denies entitlement origin changes across environment, project or package', async () => {
  for (const [label, configuration, responseOverrides] of [
    ['environment', { configuredEnvironment: 'production', configuredProjectId: 'synthetic-production-project' }, {}],
    ['project', { configuredProjectId: 'synthetic-other-development-project' }, {}],
    ['package', { configuredPackageName: 'com.example.meugestor.other' }, { packageName: 'com.example.meugestor.other' }],
  ]) {
    const h = harness();
    h.gateway.add('synthetic-purchase-token-1', response());
    await h.processor.process(request());
    const other = harness({
      ...configuration,
      storage: h.storage,
      gateway: h.gateway,
      tokenVault: h.tokenVault,
    });
    h.gateway.add('synthetic-purchase-token-2', response({
      eventId: `synthetic-event-origin-${label}`,
      eventTime: instant(11),
      ...responseOverrides,
    }));
    await rejectsCode(
      () => other.processor.process(request('synthetic-purchase-token-2')),
      'subscription_origin_transition_denied',
    );
  }
});

test('transition policy denies a source replacement in one cycle and permits a development grant replacement', () => {
  const currentGooglePlay = {
    status: 'active',
    source: 'googlePlay',
    purchaseCycleFingerprint: 'test-v1:current-cycle',
  };
  assert.throws(
    () => assertSubscriptionTransition({
      current: currentGooglePlay,
      next: { status: 'active', source: 'developmentGrant' },
      isNewPurchaseCycle: false,
    }),
    (error) => error instanceof SubscriptionError && error.code === 'subscription_source_transition_denied',
  );
  assert.doesNotThrow(() => assertSubscriptionTransition({
    current: {
      status: 'revoked',
      source: 'developmentGrant',
      revokedAt: instant(9),
      refundedAt: null,
    },
    next: {
      status: 'active',
      source: 'googlePlay',
      currentPeriodStart: instant(10),
    },
    isNewPurchaseCycle: true,
  }));
  assert.doesNotThrow(() => assertSubscriptionTransition({
    current: {
      status: 'active',
      source: 'developmentGrant',
    },
    next: {
      status: 'pending',
      source: 'googlePlay',
    },
    isNewPurchaseCycle: true,
  }));
});

test('concurrent repetition creates one revision', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await Promise.all(Array.from({ length: 8 }, () => h.processor.process(request())));
  assert.equal((await h.storage.entitlement('synthetic-user-1')).revision, 1);
});

test('failure before commit does not persist success', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  h.storage.failBeforeCommit = true;
  await rejectsCode(() => h.processor.process(request()), 'storage_unavailable_before_commit');
  assert.equal(await h.storage.entitlement('synthetic-user-1'), null);
  const [tokenReference] = h.tokenVault.storedReferences;
  await rejectsCode(
    () => h.tokenVault.retrieve(tokenReference),
    'purchase_token_not_available',
  );
});

test('concurrent duplicate cleanup only discards its own token reference after another commit', async () => {
  const storage = new DeferredDuplicateFailureStorage();
  const h = harness({ storage });
  h.gateway.add('synthetic-purchase-token-1', response());
  const first = h.processor.process(request());
  await storage.firstTransactionEntered;
  const firstReference = h.tokenVault.storedReferences[0];
  assert.equal(await h.tokenVault.retrieve(firstReference), 'synthetic-purchase-token-1');

  const second = h.processor.process(request());
  for (let turn = 0; turn < 20 && h.tokenVault.storedReferences.length < 2; turn += 1) {
    await Promise.resolve();
  }
  assert.equal(h.tokenVault.storedReferences.length, 2);
  const secondReference = h.tokenVault.storedReferences[1];
  assert.notEqual(firstReference, secondReference);
  storage.allowFirstTransactionCommit();

  const firstConfirmation = await first;
  assert.deepEqual(await second, firstConfirmation);
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const outbox = (await storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(outbox.tokenReference, firstReference);
  assert.equal(await h.tokenVault.retrieve(firstReference), 'synthetic-purchase-token-1');
  await rejectsCode(
    () => h.tokenVault.retrieve(secondReference),
    'purchase_token_not_available',
  );
});

test('timeout after commit reconciles from event', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  h.storage.failAfterCommit = true;
  assert.equal((await h.processor.process(request())).revision, 1);
  const [tokenReference] = h.tokenVault.storedReferences;
  assert.equal(
    await h.tokenVault.retrieve(tokenReference),
    'synthetic-purchase-token-1',
  );
});

test('acknowledgement outbox is repeat-safe and discards token and reference after finalization', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const [tokenReference] = h.tokenVault.storedReferences;
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 1 });
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 0 });
  assert.deepEqual(h.gateway.acknowledgements, [{ packageName, subscriptionId: 'meu_gestor_premium' }]);
  assert.doesNotMatch(JSON.stringify(h.gateway.acknowledgements), /synthetic-purchase-token-1/);
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const snapshot = await h.storage.snapshot();
  const outbox = snapshot.acknowledgementOutbox.get(fingerprint);
  assert.equal(Object.hasOwn(outbox, 'tokenReference'), false);
  assert.equal(Object.hasOwn(snapshot.bindings.get(fingerprint), 'tokenReference'), false);
  await rejectsCode(
    () => h.tokenVault.retrieve(tokenReference),
    'purchase_token_not_available',
  );
});

test('a new event for one unacknowledged purchase reuses the pending outbox reference', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const firstReference = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint).tokenReference;

  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-2',
    eventTime: instant(11),
    periodEnd: '2026-10-01T00:00:00.000Z',
  }));
  await h.processor.process(request());

  const snapshot = await h.storage.snapshot();
  const outbox = snapshot.acknowledgementOutbox.get(fingerprint);
  const secondReference = h.tokenVault.storedReferences.at(-1);
  assert.equal(outbox.state, 'pending');
  assert.equal(outbox.tokenReference, firstReference);
  assert.equal(snapshot.bindings.get(fingerprint).tokenReference, firstReference);
  assert.notEqual(secondReference, firstReference);
  assert.equal(await h.tokenVault.retrieve(firstReference), 'synthetic-purchase-token-1');
  await rejectsCode(
    () => h.tokenVault.retrieve(secondReference),
    'purchase_token_not_available',
  );
});

test('a new event does not overwrite an acknowledgement already claimed by a worker', async () => {
  const gateway = new DeferredAcknowledgementGateway();
  const h = harness({ gateway });
  gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const firstReference = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint).tokenReference;

  const worker = processAcknowledgementOutbox(h);
  await gateway.acknowledgementEntered;
  const claimed = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(claimed.state, 'claimed');
  assert.equal(claimed.tokenReference, firstReference);

  gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-during-acknowledgement',
    eventTime: instant(11),
    periodEnd: '2026-10-01T00:00:00.000Z',
  }));
  await h.processor.process(request());
  const interleaved = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  const secondReference = h.tokenVault.storedReferences.at(-1);
  assert.equal(interleaved.state, 'claimed');
  assert.equal(interleaved.claimId, claimed.claimId);
  assert.equal(interleaved.tokenReference, firstReference);
  assert.equal((await h.storage.binding(fingerprint)).tokenReference, firstReference);
  await rejectsCode(
    () => h.tokenVault.retrieve(secondReference),
    'purchase_token_not_available',
  );

  gateway.allowAcknowledgement();
  assert.deepEqual(await worker, { completed: 1 });
  const finalized = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(finalized.state, 'acknowledged');
  assert.equal(Object.hasOwn(finalized, 'tokenReference'), false);
  assert.equal(Object.hasOwn(await h.storage.binding(fingerprint), 'tokenReference'), false);
  await rejectsCode(
    () => h.tokenVault.retrieve(firstReference),
    'purchase_token_not_available',
  );
});

test('Play acknowledgement runs outside the storage transaction that claims it', async () => {
  const storage = new TransactionTrackingStorage();
  const h = harness({ storage });
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const gateway = {
    acknowledge: async (value) => {
      assert.equal(storage.activeTransactions, 0);
      return h.gateway.acknowledge(value);
    },
  };
  assert.deepEqual(await processAcknowledgementOutbox({
    storage,
    gateway,
    tokenVault: h.tokenVault,
    clock: h.clock,
    claimIdFactory: () => 'synthetic-claim-outside-transaction',
  }), { completed: 1 });
});

test('acknowledgement cleanup remains recoverable without repeating Play acknowledgement', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const [tokenReference] = h.tokenVault.storedReferences;
  h.tokenVault.discardFailuresRemaining = 1;
  await rejectsCode(
    () => processAcknowledgementOutbox(h),
    'purchase_token_cleanup_unavailable',
  );
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const pendingCleanup = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(pendingCleanup.state, 'acknowledged');
  assert.equal(Object.hasOwn(pendingCleanup, 'tokenReference'), true);
  assert.equal(h.gateway.acknowledgements.length, 1);
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 0 });
  const finalized = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(Object.hasOwn(finalized, 'tokenReference'), false);
  assert.equal(h.gateway.acknowledgements.length, 1);
  await rejectsCode(
    () => h.tokenVault.retrieve(tokenReference),
    'purchase_token_not_available',
  );
});

test('acknowledgement claim is released after failure and retried idempotently', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  h.gateway.acknowledgementFailuresRemaining = 1;
  await rejectsCode(() => processAcknowledgementOutbox(h), 'google_play_service_unavailable');
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  const pending = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(pending.state, 'pending');
  assert.equal(pending.attempts, 1);
  assert.equal(Object.hasOwn(pending, 'claimId'), false);
  assert.deepEqual(await processAcknowledgementOutbox(h), { completed: 1 });
  assert.equal(h.gateway.acknowledgementAttempts, 2);
  assert.equal(h.gateway.acknowledgements.length, 1);
  assert.equal((await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint).state, 'acknowledged');
});

test('an expired acknowledgement lease is safely reclaimed for retry', async () => {
  const h = harness(); h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
  await h.storage.transaction((state) => {
    const item = state.acknowledgementOutbox.get(fingerprint);
    state.acknowledgementOutbox.set(fingerprint, {
      ...item,
      state: 'claimed',
      attempts: 1,
      claimId: 'synthetic-expired-claim',
      leaseExpiresAt: instant(20, 11),
    });
  });
  assert.deepEqual(await processAcknowledgementOutbox({
    ...h,
    claimIdFactory: () => 'synthetic-reclaimed-claim',
  }), { completed: 1 });
  const finalized = (await h.storage.snapshot()).acknowledgementOutbox.get(fingerprint);
  assert.equal(finalized.state, 'acknowledged');
  assert.equal(finalized.attempts, 2);
});

test('RTDN rejects a mismatched project, unbound token and client environment field', async () => {
  const h = harness();
  const note = rtdnNotification({ projectId: 'other-demo-project' });
  await rejectsCode(() => processRtdn({ notification: note, ...h }), 'rtdn_environment_mismatch');
  await rejectsCode(() => processRtdn({
    notification: rtdnNotification(),
    ...h,
  }), 'rtdn_purchase_not_bound');
  await rejectsCode(() => processRtdn({
    notification: { ...rtdnNotification(), environment: 'production' },
    ...h,
  }), 'invalid_rtdn_shape');
});

test('RTDN validates the project bound to local environment before re-querying Play', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const queriesBeforeRtdn = h.gateway.queries.length;
  await rejectsCode(() => processRtdn({
    notification: rtdnNotification({ projectId: 'other-demo-project' }),
    ...h,
  }), 'rtdn_environment_mismatch');
  assert.equal(h.gateway.queries.length, queriesBeforeRtdn);
});

test('RTDN denies a binding with another locally configured project or package before re-querying Play', async () => {
  for (const incompatibleBinding of [
    { projectId: 'demo-other-project' },
    { packageName: 'com.example.other' },
  ]) {
    const h = harness();
    h.gateway.add('synthetic-purchase-token-1', response());
    await h.processor.process(request());
    const fingerprint = h.fingerprinter.fingerprint('synthetic-purchase-token-1');
    await h.storage.transaction((state) => {
      state.bindings.set(fingerprint, {
        ...state.bindings.get(fingerprint),
        ...incompatibleBinding,
      });
    });
    const queriesBeforeRtdn = h.gateway.queries.length;
    await rejectsCode(
      () => processRtdn({ notification: rtdnNotification(), ...h }),
      'rtdn_binding_environment_mismatch',
    );
    assert.equal(h.gateway.queries.length, queriesBeforeRtdn);
  }
});

test('RTDN refuses a token binding from another locally configured environment', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  const productionProcessor = new SubscriptionProcessor({
    gateway: h.gateway,
    storage: h.storage,
    fingerprinter: h.fingerprinter,
    tokenVault: h.tokenVault,
    packageName,
    environmentConfiguration: {
      environment: 'production',
      projectId: 'demo-meu-gestor-subscriptions-production',
    },
    catalog,
    accountObfuscator: () => account,
    clock: fixedNow,
  });
  await rejectsCode(() => processRtdn({
    notification: rtdnNotification({
      projectId: 'demo-meu-gestor-subscriptions-production',
    }),
    storage: h.storage,
    fingerprinter: h.fingerprinter,
    processor: productionProcessor,
  }), 'rtdn_binding_environment_mismatch');
});

test('RTDN re-queries store, derives annual plan and is idempotent', async () => {
  const h = harness();
  h.gateway.add('synthetic-purchase-token-1', response());
  await h.processor.process(request());
  h.gateway.add('synthetic-purchase-token-1', response({
    eventId: 'synthetic-event-2',
    eventTime: instant(11),
    basePlanId: 'anual',
    periodEnd: '2026-10-01T00:00:00.000Z',
  }));
  const notification = rtdnNotification();
  const first = await processRtdn({ notification, ...h });
  assert.deepEqual(await processRtdn({ notification, ...h }), first);
  assert.equal(first.revision, 2);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).planId, 'annual');
});

function grant(overrides = {}) {
  return {
    grantId: 'grant-1',
    actorId: 'synthetic-user-1',
    ownerId: 'synthetic-user-1',
    reason: 'synthetic support test',
    environment: 'development',
    source: 'developmentGrant',
    planId: 'monthly',
    validFrom: instant(1),
    validUntil: '2026-09-01T00:00:00.000Z',
    capabilities: ['investmentsManual'],
    ...overrides,
  };
}

function closedTestWindow() {
  return {
    environment: 'development',
    track: 'closed',
    startsAt: '2026-08-06T00:00:00.000Z',
    expiresAt: '2026-08-21T00:00:00.000Z',
  };
}

test('closed test grant uses the fixed server window and full fixed capabilities', async () => {
  const h = harness();
  const confirmation = await issueClosedTestGrant({
    request: { grantId: 'closed-test-1', ownerId: 'synthetic-user-1', track: 'closed' },
    window: closedTestWindow(),
    authorizedOwnerIds: new Set(['synthetic-user-1']),
    storage: h.storage,
    clock: fixedNow,
  });
  const entitlement = await h.storage.entitlement('synthetic-user-1');
  assert.equal(confirmation.status, 'active');
  assert.equal(entitlement.source, 'closedTestGrant');
  assert.equal(entitlement.capabilities.length, 5);
  assert.equal(entitlement.currentPeriodStart, closedTestWindow().startsAt);
  assert.equal(entitlement.currentPeriodEnd, closedTestWindow().expiresAt);
  assert.equal(JSON.stringify(await h.storage.audits()).includes('synthetic-user-1'), false);
});

test('closed test grant denies unauthorized, production, reuse and expires only by server clock', async () => {
  const h = harness();
  const requestValue = { grantId: 'closed-test-1', ownerId: 'synthetic-user-1', track: 'closed' };
  await rejectsCode(() => issueClosedTestGrant({ request: requestValue, window: closedTestWindow(), authorizedOwnerIds: new Set(), storage: h.storage, clock: fixedNow }), 'closed_test_tester_not_authorized');
  await rejectsCode(() => issueClosedTestGrant({ request: requestValue, window: { ...closedTestWindow(), environment: 'production' }, authorizedOwnerIds: new Set(['synthetic-user-1']), storage: h.storage, clock: fixedNow }), 'closed_test_production_denied');
  await issueClosedTestGrant({ request: requestValue, window: closedTestWindow(), authorizedOwnerIds: new Set(['synthetic-user-1']), storage: h.storage, clock: fixedNow });
  assert.deepEqual(
    await issueClosedTestGrant({ request: requestValue, window: closedTestWindow(), authorizedOwnerIds: new Set(['synthetic-user-1']), storage: h.storage, clock: fixedNow }),
    { status: 'active', revision: 1, requiresServerRefresh: true },
  );
  await rejectsCode(() => issueClosedTestGrant({ request: { ...requestValue, ownerId: 'synthetic-user-2' }, window: closedTestWindow(), authorizedOwnerIds: new Set(['synthetic-user-1', 'synthetic-user-2']), storage: h.storage, clock: fixedNow }), 'closed_test_grant_id_conflict');
  await rejectsCode(() => issueClosedTestGrant({ request: { ...requestValue, grantId: 'closed-test-2', track: 'internal' }, window: closedTestWindow(), authorizedOwnerIds: new Set(['synthetic-user-1']), storage: h.storage, clock: fixedNow }), 'closed_test_track_mismatch');
  assert.deepEqual(await expireClosedTestGrants({ window: closedTestWindow(), storage: h.storage, clock: fixedNow }), { expired: 0 });
  const afterWindow = () => new Date('2026-08-21T00:00:00.000Z');
  assert.deepEqual(await expireClosedTestGrants({ window: closedTestWindow(), storage: h.storage, clock: afterWindow }), { expired: 1 });
  assert.equal((await h.storage.entitlement('synthetic-user-1')).status, 'expired');
});

test('development grant is scoped, audited and idempotent', async () => {
  const h = harness();
  const first = await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow });
  assert.deepEqual(await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow }), first);
  assert.equal((await h.storage.entitlement('synthetic-user-1')).capabilities.length, 1);
});

test('development grant never targets production', async () => {
  const h = harness();
  await rejectsCode(() => applyAdministrativeGrant({
    request: grant({ environment: 'production' }),
    storage: h.storage,
    clock: fixedNow,
  }), 'development_grant_in_production');
});

test('grant denies cross-user and unknown capability', async () => {
  const h = harness();
  await rejectsCode(() => applyAdministrativeGrant({
    request: grant({ ownerId: 'synthetic-user-2' }),
    storage: h.storage,
    clock: fixedNow,
  }), 'grant_actor_denied');
  await rejectsCode(() => applyAdministrativeGrant({
    request: grant({ capabilities: ['unknownCapability'] }),
    storage: h.storage,
    clock: fixedNow,
  }), 'invalid_grant_scope');
});

test('grant revocation is terminal and idempotent', async () => {
  const h = harness();
  await applyAdministrativeGrant({ request: grant(), storage: h.storage, clock: fixedNow });
  const args = {
    grantId: 'grant-1',
    actorId: 'synthetic-user-1',
    ownerId: 'synthetic-user-1',
    reason: 'synthetic revocation',
    storage: h.storage,
    clock: fixedNow,
  };
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

test('in-memory token vault rejects a malformed reference', async () => {
  const vault = new InMemoryPurchaseTokenVault();
  await rejectsCode(() => vault.retrieve('other-vault:synthetic'), 'invalid_token_reference');
});

test('external account identifier is irreversibly derived by backend', () => {
  const first = createObfuscatedExternalAccountId({ uid: 'synthetic-user-1', key: 'synthetic-account-key' });
  const repeated = createObfuscatedExternalAccountId({ uid: 'synthetic-user-1', key: 'synthetic-account-key' });
  const other = createObfuscatedExternalAccountId({ uid: 'synthetic-user-2', key: 'synthetic-account-key' });
  assert.equal(first, repeated);
  assert.notEqual(first, other);
  assert.doesNotMatch(first, /synthetic-user-1/);
});
