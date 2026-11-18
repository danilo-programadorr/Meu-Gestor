import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, describe, test } from 'node:test';

import {
  CLOSED_TEST_GRANTS_COLLECTION,
  CLOSED_TEST_TESTERS_COLLECTION,
  createFirestoreClosedTestActivation,
} from '../src/closed_test_activation.mjs';
import { createFirebasePremiumCallables } from '../src/firebase_callables.mjs';
import { createClosedTestGrantId } from '../../../subscriptions/src/closed_test_grants.mjs';

/// Exercita o SDK real e a lógica existente somente no Emulator local, sem ADC,
/// rede Cloud, dados reais ou substituição das transações por armazenamento falso.
const enabled = process.env.FIRESTORE_EMULATOR_HOST !== undefined;
const suite = enabled ? describe : describe.skip;
const runId = randomUUID();
let app;
let firestore;
let Timestamp;
let deleteApp;

/// Cada execução começa sem concessões próprias, mesmo ao reutilizar o mesmo
/// Emulator: histórico de outra rodada não pode tornar o teste falso-positivo.
function syntheticOwner(label) {
  return `synthetic-sdk-${runId}-${label}`;
}

async function assertNoGrant(ownerId) {
  const refs = references(ownerId);
  assert.equal((await refs.grant.get()).exists, false);
  assert.equal((await refs.entitlement.get()).exists, false);
}

function activation(clock = () => new Date('2026-08-20T12:00:00.000Z')) {
  return createFirestoreClosedTestActivation({
    firestore,
    timestampFromDate: Timestamp.fromDate,
    environment: 'development',
    clock,
  });
}

function references(ownerId) {
  return {
    tester: firestore.doc(`${CLOSED_TEST_TESTERS_COLLECTION}/${ownerId}`),
    grant: firestore.doc(`${CLOSED_TEST_GRANTS_COLLECTION}/${createClosedTestGrantId(ownerId)}`),
    entitlement: firestore.doc(`users/${ownerId}/entitlements/premium`),
  };
}

async function authorize(ownerId, overrides = {}) {
  await assertNoGrant(ownerId);
  await references(ownerId).tester.set({
    environment: 'development',
    track: 'closed',
    status: 'active',
    authorizedAt: Timestamp.fromDate(new Date('2026-08-20T12:00:00.000Z')),
    revision: 1,
    schemaVersion: 1,
    ...overrides,
  });
}

function profile(ownerId) {
  const timestamp = Timestamp.fromDate(new Date('2026-08-20T12:00:00.000Z'));
  return {
    ownerId,
    displayName: 'Usuário sintético',
    locale: 'pt-BR',
    currencyCode: 'BRL',
    timeZone: 'America/Sao_Paulo',
    emailVerifiedSnapshot: true,
    termsVersionAccepted: 'terms-dev-1.0.0',
    termsAcceptedAt: timestamp,
    privacyVersionAccepted: 'privacy-dev-1.0.0',
    privacyAcceptedAt: timestamp,
    aiConsentEnabled: false,
    aiConsentUpdatedAt: timestamp,
    analyticsConsentEnabled: false,
    analyticsConsentUpdatedAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
    schemaVersion: 1,
  };
}

suite('Premium with the real Admin/Firestore SDK on the local Emulator', { timeout: 60000 }, () => {
  before(async () => {
    if (!/^(?:127\.0\.0\.1|localhost):[0-9]+$/u.test(process.env.FIRESTORE_EMULATOR_HOST)) {
      throw new Error('premium_test_requires_local_emulator');
    }
    const appModule = await import('firebase-admin/app');
    const firestoreModule = await import('firebase-admin/firestore');
    deleteApp = appModule.deleteApp;
    Timestamp = firestoreModule.Timestamp;
    app = appModule.initializeApp({ projectId: 'demo-meu-gestor-financeiro' }, 'premium-sdk-emulator');
    firestore = firestoreModule.getFirestore(app);
  });

  after(async () => {
    if (firestore) await firestore.terminate();
    if (app) await deleteApp(app);
  });

  test('modular imports, reads, Timestamp roundtrip and callable serialization remain compatible', async () => {
    const ownerId = syntheticOwner('contract');
    await authorize(ownerId);
    await firestore.doc(`users/${ownerId}`).set(profile(ownerId));
    assert.deepEqual(await activation().activate({ ownerId }), {
      status: 'active', revision: 1, requiresServerRefresh: true,
    });
    const stored = (await references(ownerId).entitlement.get()).data();
    assert.ok(stored.currentPeriodEnd instanceof Timestamp);
    assert.equal(stored.currentPeriodEnd.toDate().toISOString(), '2026-09-04T12:00:00.000Z');
    const { HttpsError } = await import('firebase-functions/v2/https');
    const callables = createFirebasePremiumCallables({
      onCall: (_options, handler) => handler,
      HttpsError,
      firestore,
    });
    const result = await callables.getConfirmedEntitlement({
      auth: { uid: ownerId, token: { email_verified: true } },
      app: { appId: 'synthetic-app' },
      data: {},
    });
    assert.equal(result.entitlement.ownerId, ownerId);
    assert.equal(result.entitlement.currentPeriodEnd, '2026-09-04T12:00:00.000Z');
    assert.equal(result.entitlement.source, 'closedTestGrant');
    assert.equal(result.entitlement.capabilities.length, 5);
    assert.equal(result.requiresServerRefresh, false);
  });

  /// Concorrência disputa os mesmos documentos reais; repetições não renovam
  /// prazo, duplicam concessões ou alteram o entitlement de outro proprietário.
  test('concurrent activations and a later retry preserve a single atomic grant', async () => {
    const ownerId = syntheticOwner('concurrent');
    const otherId = syntheticOwner('independent');
    await authorize(ownerId);
    await authorize(otherId);
    await activation().activate({ ownerId: otherId });
    const otherBefore = (await references(otherId).entitlement.get()).data();
    const results = await Promise.all(Array.from({ length: 4 }, () => activation().activate({ ownerId })));
    for (const result of results) {
      assert.deepEqual(result, { status: 'active', revision: 1, requiresServerRefresh: true });
    }
    const refs = references(ownerId);
    const grantBefore = (await refs.grant.get()).data();
    const entitlementBefore = (await refs.entitlement.get()).data();
    assert.equal(grantBefore.ownerId, ownerId);
    assert.equal(grantBefore.revision, entitlementBefore.revision);
    assert.ok(grantBefore.startsAt.isEqual(entitlementBefore.currentPeriodStart));
    assert.ok(grantBefore.expiresAt.isEqual(entitlementBefore.currentPeriodEnd));
    assert.equal(JSON.stringify(grantBefore.audit).includes(ownerId), false);
    await activation(() => new Date('2026-08-21T12:00:00.000Z')).activate({ ownerId });
    assert.deepEqual((await refs.grant.get()).data(), grantBefore);
    assert.deepEqual((await refs.entitlement.get()).data(), entitlementBefore);
    assert.deepEqual((await references(otherId).entitlement.get()).data(), otherBefore);
    const grants = await firestore.collection(CLOSED_TEST_GRANTS_COLLECTION).where('ownerId', '==', ownerId).get();
    assert.equal(grants.size, 1);
  });

  test('missing, revoked or malformed authorization fails closed without granting access', async () => {
    const cases = [
      [syntheticOwner('absent'), null, 'closed_test_tester_not_authorized'],
      [syntheticOwner('revoked'), { status: 'revoked' }, 'closed_test_tester_not_authorized'],
      [syntheticOwner('invalid'), { schemaVersion: 99 }, 'invalid_closed_test_tester_record'],
    ];
    for (const [ownerId, record, code] of cases) {
      if (record) await authorize(ownerId, record);
      else await assertNoGrant(ownerId);
      await assert.rejects(() => activation().activate({ ownerId }), (error) => error.code === code);
      assert.equal((await references(ownerId).grant.get()).exists, false);
      assert.equal((await references(ownerId).entitlement.get()).exists, false);
    }
  });

  test('an invalid existing entitlement aborts the transaction without overwriting data', async () => {
    const ownerId = syntheticOwner('integrity');
    await authorize(ownerId);
    const refs = references(ownerId);
    const invalid = { source: 'closedTestGrant', status: 'active', currentPeriodEnd: 'invalid' };
    await refs.entitlement.set(invalid);
    await assert.rejects(
      () => activation().activate({ ownerId }),
      (error) => error.code === 'closed_test_grant_integrity_denied',
    );
    assert.deepEqual((await refs.entitlement.get()).data(), invalid);
    assert.equal((await refs.grant.get()).exists, false);
  });

  test('expiration updates grant and entitlement together and remains idempotent', async () => {
    const ownerId = syntheticOwner('expiry');
    await authorize(ownerId);
    assert.deepEqual(await activation().activate({ ownerId }), {
      status: 'active', revision: 1, requiresServerRefresh: true,
    });
    const expired = activation(() => new Date('2026-09-04T12:00:00.000Z'));
    assert.deepEqual(await expired.activate({ ownerId }), {
      status: 'expired', revision: 2, requiresServerRefresh: true,
    });
    const refs = references(ownerId);
    const grant = (await refs.grant.get()).data();
    const entitlement = (await refs.entitlement.get()).data();
    assert.equal(grant.status, 'expired');
    assert.equal(grant.revision, entitlement.revision);
    assert.deepEqual(entitlement.capabilities, []);
    assert.equal(entitlement.expiredAt.toDate().toISOString(), '2026-09-04T12:00:00.000Z');
    await expired.activate({ ownerId });
    assert.deepEqual((await refs.grant.get()).data(), grant);
    assert.deepEqual((await refs.entitlement.get()).data(), entitlement);
  });
});
