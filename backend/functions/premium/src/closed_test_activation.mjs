import {
  authorizeClosedTestTester,
  createClosedTestGrantId,
  issueClosedTestGrant,
  revokeClosedTestTester,
} from '../.generated/subscriptions/src/closed_test_grants.mjs';
import { deny, requireText, requireUtcInstant } from '../.generated/subscriptions/src/errors.mjs';

export const CLOSED_TEST_TESTERS_COLLECTION = '_premiumClosedTestTesters';
export const CLOSED_TEST_GRANTS_COLLECTION = '_premiumClosedTestGrants';

/// Adaptador Admin-only para a ativação pelo próprio testador. A lista fica
/// numa coleção interna, indexada pelo UID e sem e-mail. O cliente não recebe
/// seu conteúdo nem escreve nesses caminhos; as Rules os negam integralmente.
export function createFirestoreClosedTestActivation({ firestore, timestampFromDate, environment, clock = () => new Date() }) {
  if (!firestore || typeof firestore.doc !== 'function' || typeof firestore.runTransaction !== 'function') {
    throw new TypeError('Invalid closed test Firestore dependencies.');
  }
  if (typeof timestampFromDate !== 'function' || typeof clock !== 'function' || environment === undefined) {
    throw new TypeError('Invalid closed test clock dependencies.');
  }
  return Object.freeze({
    activate: async ({ ownerId }) => {
      assertDevelopmentEnvironment(environment);
      requireText(ownerId, 'invalid_closed_test_owner_id');
      const storage = new FirestoreClosedTestActivationStorage({ firestore, ownerId, timestampFromDate });
      return issueClosedTestGrant({
        request: { grantId: createClosedTestGrantId(ownerId), ownerId, track: 'closed' },
        storage,
        clock,
      });
    },
  });
}

/// Serviço administrativo futuro, deliberadamente sem callable/export público.
/// A identidade administrativa deverá ser verificada no perímetro antes de
/// chamar estas operações; o aplicativo nunca recebe esse adaptador.
export function createFirestoreClosedTestAuthorization({ firestore, timestampFromDate, environment, clock = () => new Date() }) {
  if (!firestore || typeof firestore.doc !== 'function' || typeof firestore.runTransaction !== 'function') {
    throw new TypeError('Invalid closed test Firestore dependencies.');
  }
  if (typeof timestampFromDate !== 'function' || typeof clock !== 'function' || environment === undefined) {
    throw new TypeError('Invalid closed test clock dependencies.');
  }
  return Object.freeze({
    authorize: async ({ ownerId }) => {
      assertDevelopmentEnvironment(environment);
      return authorizeClosedTestTester({
        request: { ownerId, track: 'closed' },
        storage: new FirestoreClosedTestAuthorizationStorage({ firestore, ownerId, timestampFromDate }),
        clock,
      });
    },
    revoke: async ({ ownerId }) => {
      assertDevelopmentEnvironment(environment);
      return revokeClosedTestTester({
        request: { ownerId, track: 'closed' },
        storage: new FirestoreClosedTestAuthorizationStorage({ firestore, ownerId, timestampFromDate }),
        clock,
      });
    },
  });
}

class FirestoreClosedTestActivationStorage {
  constructor({ firestore, ownerId, timestampFromDate }) {
    this.firestore = firestore;
    this.ownerId = ownerId;
    this.timestampFromDate = timestampFromDate;
  }

  async transaction(operation) {
    if (typeof operation !== 'function') throw deny('invalid_closed_test_transaction');
    return this.firestore.runTransaction(async (transaction) => {
      const refs = this.#references();
      const [testerSnapshot, grantSnapshot, entitlementSnapshot] = await Promise.all([
        transaction.get(refs.tester),
        transaction.get(refs.grant),
        transaction.get(refs.entitlement),
      ]);
      const state = {
        entitlements: new Map(),
        grants: new Map(),
        closedTestTesters: new Map(),
        audits: [],
      };
      if (testerSnapshot.exists) state.closedTestTesters.set(this.ownerId, decodeTester(testerSnapshot.data()));
      if (grantSnapshot.exists) state.grants.set(refs.grantId, decodeGrant(grantSnapshot.data()));
      if (entitlementSnapshot.exists) state.entitlements.set(this.ownerId, decodeEntitlement(entitlementSnapshot.data()));
      const result = await operation(state);
      const entitlement = state.entitlements.get(this.ownerId);
      const grant = state.grants.get(refs.grantId);
      if (entitlement === undefined || grant === undefined) throw deny('closed_test_grant_integrity_denied');
      transaction.set(refs.entitlement, encodeEntitlement(entitlement, this.timestampFromDate));
      transaction.set(refs.grant, encodeGrant(grant, this.timestampFromDate));
      return structuredClone(result);
    });
  }

  #references() {
    const grantId = createClosedTestGrantId(this.ownerId);
    return Object.freeze({
      grantId,
      tester: this.firestore.doc(`${CLOSED_TEST_TESTERS_COLLECTION}/${this.ownerId}`),
      grant: this.firestore.doc(`${CLOSED_TEST_GRANTS_COLLECTION}/${grantId}`),
      entitlement: this.firestore.doc(`users/${this.ownerId}/entitlements/premium`),
    });
  }
}

class FirestoreClosedTestAuthorizationStorage {
  constructor({ firestore, ownerId, timestampFromDate }) {
    this.firestore = firestore;
    this.ownerId = requireText(ownerId, 'invalid_closed_test_owner_id');
    this.timestampFromDate = timestampFromDate;
  }

  async transaction(operation) {
    if (typeof operation !== 'function') throw deny('invalid_closed_test_transaction');
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.firestore.doc(`${CLOSED_TEST_TESTERS_COLLECTION}/${this.ownerId}`);
      const snapshot = await transaction.get(reference);
      const state = {
        entitlements: new Map(),
        grants: new Map(),
        closedTestTesters: new Map(),
        audits: [],
      };
      if (snapshot.exists) state.closedTestTesters.set(this.ownerId, decodeTester(snapshot.data()));
      const result = await operation(state);
      const tester = state.closedTestTesters.get(this.ownerId);
      if (tester === undefined) throw deny('closed_test_tester_integrity_denied');
      transaction.set(reference, encodeTester(tester, this.timestampFromDate));
      return structuredClone(result);
    });
  }
}

function decodeTester(value) {
  return Object.freeze({
    ...value,
    authorizedAt: timestampToIso(value?.authorizedAt, 'invalid_closed_test_tester_record'),
  });
}

function encodeTester(value, timestampFromDate) {
  return Object.freeze({
    ...value,
    authorizedAt: timestampFromDate(new Date(value.authorizedAt)),
  });
}

function decodeGrant(value) {
  return Object.freeze({
    ...value,
    startsAt: timestampToIso(value?.startsAt, 'invalid_closed_test_grant_record'),
    expiresAt: timestampToIso(value?.expiresAt, 'invalid_closed_test_grant_record'),
    audit: value?.audit === null || typeof value?.audit !== 'object'
      ? value?.audit
      : Object.freeze({ ...value.audit, at: timestampToIso(value.audit.at, 'invalid_closed_test_grant_record') }),
  });
}

function decodeEntitlement(value) {
  const timestampFields = [
    'startedAt', 'currentPeriodStart', 'currentPeriodEnd', 'lastVerifiedAt', 'createdAt', 'updatedAt',
  ];
  const nullableTimestampFields = ['graceUntil', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt'];
  const result = { ...value };
  for (const field of timestampFields) result[field] = timestampToIso(value?.[field], 'closed_test_grant_integrity_denied');
  for (const field of nullableTimestampFields) {
    result[field] = value?.[field] === null ? null : timestampToIso(value?.[field], 'closed_test_grant_integrity_denied');
  }
  return Object.freeze(result);
}

function encodeGrant(value, timestampFromDate) {
  return Object.freeze({
    ...value,
    startsAt: timestampFromDate(new Date(value.startsAt)),
    expiresAt: timestampFromDate(new Date(value.expiresAt)),
    audit: Object.freeze({ ...value.audit, at: timestampFromDate(new Date(value.audit.at)) }),
  });
}

function encodeEntitlement(value, timestampFromDate) {
  const timestampFields = [
    'startedAt', 'currentPeriodStart', 'currentPeriodEnd', 'lastVerifiedAt', 'createdAt', 'updatedAt',
  ];
  const nullableTimestampFields = ['graceUntil', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt'];
  const result = { ...value };
  for (const field of timestampFields) result[field] = timestampFromDate(new Date(value[field]));
  for (const field of nullableTimestampFields) {
    result[field] = value[field] === null ? null : timestampFromDate(new Date(value[field]));
  }
  return Object.freeze(result);
}

function timestampToIso(value, code) {
  if (value === null || typeof value !== 'object' || typeof value.toDate !== 'function') throw deny(code);
  return requireUtcInstant(value.toDate().toISOString(), code).toISOString();
}

function assertDevelopmentEnvironment(environment) {
  const resolved = typeof environment === 'function' ? environment() : environment;
  if (resolved !== 'development') throw deny('closed_test_environment_denied');
}
