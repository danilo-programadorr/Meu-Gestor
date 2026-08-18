import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CLOSED_TEST_GRANTS_COLLECTION,
  CLOSED_TEST_TESTERS_COLLECTION,
  createFirestoreClosedTestAuthorization,
  createFirestoreClosedTestActivation,
} from '../src/closed_test_activation.mjs';
import { createClosedTestGrantId } from '../../../subscriptions/src/closed_test_grants.mjs';

function timestamp(value) {
  const date = value instanceof Date ? value : new Date(value);
  return Object.freeze({ toDate: () => new Date(date) });
}

function fakeFirestore(seed = {}) {
  let documents = new Map(Object.entries(seed));
  return {
    doc: (path) => Object.freeze({ path }),
    runTransaction: async (operation) => {
      const draft = new Map(documents);
      const transaction = {
        get: async (reference) => Object.freeze({
          exists: draft.has(reference.path),
          data: () => draft.get(reference.path),
        }),
        set: (reference, value) => draft.set(reference.path, value),
      };
      const result = await operation(transaction);
      documents = draft;
      return result;
    },
    read: (path) => documents.get(path),
  };
}

function activeTester() {
  return {
    environment: 'development',
    track: 'closed',
    status: 'active',
    authorizedAt: timestamp('2026-08-20T12:00:00.000Z'),
    revision: 1,
    schemaVersion: 1,
  };
}

test('authorized internal tester receives an individual server-timed grant without an e-mail field', async () => {
  const uid = 'synthetic-tester-1';
  const firestore = fakeFirestore({ [`${CLOSED_TEST_TESTERS_COLLECTION}/${uid}`]: activeTester() });
  const service = createFirestoreClosedTestActivation({
    firestore,
    timestampFromDate: timestamp,
    environment: 'development',
    clock: () => new Date('2026-08-20T12:00:00.000Z'),
  });
  assert.deepEqual(
    await service.activate({ ownerId: uid }),
    { status: 'active', revision: 1, requiresServerRefresh: true },
  );
  const entitlement = firestore.read(`users/${uid}/entitlements/premium`);
  assert.equal(entitlement.source, 'closedTestGrant');
  assert.equal(entitlement.currentPeriodEnd.toDate().toISOString(), '2026-09-04T12:00:00.000Z');
  assert.equal(entitlement.capabilities.length, 5);
  assert.equal(Object.hasOwn(entitlement, 'email'), false);
  const grant = firestore.read(`${CLOSED_TEST_GRANTS_COLLECTION}/${createClosedTestGrantId(uid)}`);
  assert.equal(grant.audit.action, 'issued');
  assert.equal(JSON.stringify(grant.audit).includes(uid), false);
});

test('activation fails closed without a private authorization and cannot restore an expired grant', async () => {
  const uid = 'synthetic-tester-2';
  const firestore = fakeFirestore({ [`${CLOSED_TEST_TESTERS_COLLECTION}/${uid}`]: activeTester() });
  let now = new Date('2026-08-20T12:00:00.000Z');
  const service = createFirestoreClosedTestActivation({
    firestore, timestampFromDate: timestamp, environment: 'development', clock: () => now,
  });
  await service.activate({ ownerId: uid });
  now = new Date('2026-09-04T12:00:00.000Z');
  assert.deepEqual(
    await service.activate({ ownerId: uid }),
    { status: 'expired', revision: 2, requiresServerRefresh: true },
  );
  assert.equal(firestore.read(`users/${uid}/entitlements/premium`).status, 'expired');
  const blocked = createFirestoreClosedTestActivation({
    firestore: fakeFirestore(), timestampFromDate: timestamp, environment: 'development', clock: () => now,
  });
  await assert.rejects(
    () => blocked.activate({ ownerId: 'synthetic-unlisted' }),
    (error) => error.code === 'closed_test_tester_not_authorized',
  );
});

test('administrative authorization writes only the private UID-keyed directory and preserves revocation history', async () => {
  const uid = 'synthetic-tester-3';
  const firestore = fakeFirestore();
  const service = createFirestoreClosedTestAuthorization({
    firestore,
    timestampFromDate: timestamp,
    environment: 'development',
    clock: () => new Date('2026-08-20T12:00:00.000Z'),
  });
  assert.deepEqual(
    await service.authorize({ ownerId: uid }),
    { status: 'authorized', revision: 1, requiresServerRefresh: true },
  );
  const record = firestore.read(`${CLOSED_TEST_TESTERS_COLLECTION}/${uid}`);
  assert.equal(record.environment, 'development');
  assert.equal(record.track, 'closed');
  assert.equal(Object.hasOwn(record, 'email'), false);
  assert.deepEqual(
    await service.revoke({ ownerId: uid }),
    { status: 'revoked', revision: 2, requiresServerRefresh: true },
  );
  assert.equal(firestore.read(`${CLOSED_TEST_TESTERS_COLLECTION}/${uid}`).status, 'revoked');
});

test('closed test services fail closed outside the explicit development environment', async () => {
  const firestore = fakeFirestore();
  const service = createFirestoreClosedTestActivation({
    firestore,
    timestampFromDate: timestamp,
    environment: 'production',
    clock: () => new Date('2026-08-20T12:00:00.000Z'),
  });
  await assert.rejects(
    () => service.activate({ ownerId: 'synthetic-tester-production' }),
    (error) => error.code === 'closed_test_environment_denied',
  );
  assert.equal(firestore.read('users/synthetic-tester-production/entitlements/premium'), undefined);
});
