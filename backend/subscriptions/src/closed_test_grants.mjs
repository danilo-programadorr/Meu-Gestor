import { createHash } from 'node:crypto';

import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';
import { PREMIUM_CAPABILITIES } from './mapper.mjs';

export const CLOSED_TEST_DURATION_MS = 15 * 24 * 60 * 60 * 1000;

const ACTIVATION_REQUEST_FIELDS = Object.freeze(['grantId', 'ownerId', 'track']);
const AUTHORIZATION_REQUEST_FIELDS = Object.freeze(['ownerId', 'track']);
const TESTER_FIELDS = Object.freeze([
  'environment', 'track', 'status', 'authorizedAt', 'revision', 'schemaVersion',
]);
const GRANT_FIELDS = Object.freeze([
  'kind', 'ownerId', 'track', 'status', 'startsAt', 'expiresAt', 'revision',
  'schemaVersion', 'audit',
]);

/// Identificador opaco e estável, gerado no servidor somente para manter a
/// idempotência. Ele não é autorização, não é entregue ao aplicativo e não
/// contém o UID em texto puro.
export function createClosedTestGrantId(ownerId) {
  requireText(ownerId, 'invalid_closed_test_owner_id');
  return `closed-test-v1-${createHash('sha256').update(`closed-test-v1:${ownerId}`).digest('base64url')}`;
}

/// Caminho administrativo futuro: autoriza um UID já conhecido pelo backend.
/// O aplicativo não chama esta rotina, não grava a lista e não recebe seus
/// metadados. Não há e-mail ou outro identificador externo no registro.
export async function authorizeClosedTestTester({ request, storage, clock }) {
  requireExactObject(request, AUTHORIZATION_REQUEST_FIELDS, 'invalid_closed_test_authorization_request');
  const ownerId = requireText(request.ownerId, 'invalid_closed_test_owner_id');
  const track = requireClosedTrack(request.track);
  const now = trustedNow(clock);
  return storage.transaction((state) => {
    requireClosedTestState(state);
    const previous = state.closedTestTesters.get(ownerId);
    if (previous !== undefined) {
      assertTesterRecord(previous);
      if (previous.status === 'active' && previous.track === track) {
        return Object.freeze({ status: 'authorized', revision: previous.revision, requiresServerRefresh: true });
      }
    }
    const record = Object.freeze({
      environment: 'development',
      track,
      status: 'active',
      authorizedAt: now.toISOString(),
      revision: (previous?.revision ?? 0) + 1,
      schemaVersion: 1,
    });
    state.closedTestTesters.set(ownerId, record);
    state.audits.push(sanitizedAudit({
      action: 'authorized',
      track,
      revision: record.revision,
      at: now.toISOString(),
    }));
    return Object.freeze({ status: 'authorized', revision: record.revision, requiresServerRefresh: true });
  });
}

/// Revogação remove a elegibilidade futura sem excluir histórico. Uma
/// concessão já emitida é preservada e expira pelo próprio prazo individual.
export async function revokeClosedTestTester({ request, storage, clock }) {
  requireExactObject(request, AUTHORIZATION_REQUEST_FIELDS, 'invalid_closed_test_authorization_request');
  const ownerId = requireText(request.ownerId, 'invalid_closed_test_owner_id');
  const track = requireClosedTrack(request.track);
  const now = trustedNow(clock);
  return storage.transaction((state) => {
    requireClosedTestState(state);
    const previous = state.closedTestTesters.get(ownerId);
    if (previous === undefined) throw deny('closed_test_tester_not_authorized');
    assertTesterRecord(previous);
    if (previous.track !== track) throw deny('closed_test_track_mismatch');
    if (previous.status === 'revoked') {
      return Object.freeze({ status: 'revoked', revision: previous.revision, requiresServerRefresh: true });
    }
    const record = Object.freeze({ ...previous, status: 'revoked', revision: previous.revision + 1 });
    state.closedTestTesters.set(ownerId, record);
    state.audits.push(sanitizedAudit({
      action: 'authorizationRevoked', track, revision: record.revision, at: now.toISOString(),
    }));
    return Object.freeze({ status: 'revoked', revision: record.revision, requiresServerRefresh: true });
  });
}

/// Emite somente para o próprio UID de um chamador já validado pela borda.
/// A duração é individual e nasce do relógio confiável do servidor; não há
/// janela global, primeira abertura local, oferta Play ou preço neste fluxo.
export async function issueClosedTestGrant({ request, storage, clock }) {
  requireExactObject(request, ACTIVATION_REQUEST_FIELDS, 'invalid_closed_test_grant_request');
  const grantId = requireText(request.grantId, 'invalid_closed_test_grant_id', 256);
  const ownerId = requireText(request.ownerId, 'invalid_closed_test_owner_id');
  const track = requireClosedTrack(request.track);
  const now = trustedNow(clock);
  return storage.transaction((state) => {
    requireClosedTestState(state);
    materializeOwnerExpiration({ state, ownerId, now });
    const existing = findOwnerGrant(state, ownerId);
    if (existing !== null) {
      assertGrantRecord(existing.record);
      if (existing.record.track !== track) throw deny('closed_test_track_mismatch');
      const entitlement = state.entitlements.get(ownerId);
      if (entitlement === undefined) throw deny('closed_test_grant_integrity_denied');
      return confirmation(entitlement);
    }
    const tester = state.closedTestTesters.get(ownerId);
    if (tester === undefined) throw deny('closed_test_tester_not_authorized');
    assertTesterRecord(tester);
    if (tester.status !== 'active') throw deny('closed_test_tester_not_authorized');
    if (tester.track !== track) throw deny('closed_test_track_mismatch');
    const current = state.entitlements.get(ownerId);
    if (current !== undefined) throw deny('closed_test_entitlement_conflict');
    const startsAt = now.toISOString();
    const expiresAt = new Date(now.valueOf() + CLOSED_TEST_DURATION_MS).toISOString();
    const projection = Object.freeze({
      ownerId,
      planId: 'monthly',
      status: 'active',
      source: 'closedTestGrant',
      environment: 'development',
      capabilities: [...PREMIUM_CAPABILITIES],
      startedAt: startsAt,
      currentPeriodStart: startsAt,
      currentPeriodEnd: expiresAt,
      graceUntil: null,
      cancelAtPeriodEnd: false,
      cancelledAt: null,
      expiredAt: null,
      revokedAt: null,
      refundedAt: null,
      lastVerifiedAt: startsAt,
      revision: 1,
      schemaVersion: 1,
      createdAt: startsAt,
      updatedAt: startsAt,
    });
    const audit = sanitizedAudit({ action: 'issued', track, revision: projection.revision, at: startsAt });
    const grant = Object.freeze({
      kind: 'closedTestGrant', ownerId, track, status: 'active', startsAt, expiresAt,
      revision: 1, schemaVersion: 1, audit,
    });
    state.entitlements.set(ownerId, projection);
    state.grants.set(grantId, grant);
    state.audits.push(audit);
    return confirmation(projection);
  });
}

/// Materializa o vencimento com relógio de servidor, sem excluir entitlements
/// ou dados Premium. A mesma rotina é idempotente e nunca recria concessões.
export async function expireClosedTestGrants({ storage, clock }) {
  const now = trustedNow(clock);
  return storage.transaction((state) => {
    requireClosedTestState(state);
    let expired = 0;
    for (const [ownerId, entitlement] of state.entitlements) {
      if (materializeOwnerExpiration({ state, ownerId, now, entitlement })) expired += 1;
    }
    return Object.freeze({ expired });
  });
}

function materializeOwnerExpiration({ state, ownerId, now, entitlement = state.entitlements.get(ownerId) }) {
  if (entitlement === undefined || entitlement.source !== 'closedTestGrant' || entitlement.status !== 'active') {
    return false;
  }
  const expiresAt = requireUtcInstant(entitlement.currentPeriodEnd, 'invalid_closed_test_expiration');
  if (now < expiresAt) return false;
  const expired = Object.freeze({
    ...entitlement,
    status: 'expired',
    capabilities: [],
    expiredAt: expiresAt.toISOString(),
    lastVerifiedAt: now.toISOString(),
    updatedAt: now.toISOString(),
    revision: entitlement.revision + 1,
  });
  state.entitlements.set(ownerId, expired);
  const grant = findOwnerGrant(state, ownerId);
  if (grant !== null) {
    assertGrantRecord(grant.record);
    state.grants.set(grant.grantId, Object.freeze({
      ...grant.record,
      status: 'expired',
      revision: grant.record.revision + 1,
      audit: sanitizedAudit({
        action: 'expired', track: grant.record.track, revision: grant.record.revision + 1, at: now.toISOString(),
      }),
    }));
  }
  state.audits.push(sanitizedAudit({
    action: 'expired', track: 'closed', revision: expired.revision, at: now.toISOString(),
  }));
  return true;
}

function findOwnerGrant(state, ownerId) {
  for (const [grantId, record] of state.grants) {
    if (record?.kind === 'closedTestGrant' && record.ownerId === ownerId) {
      return Object.freeze({ grantId, record });
    }
  }
  return null;
}

function requireClosedTestState(state) {
  if (
    state === null || typeof state !== 'object' ||
    !(state.entitlements instanceof Map) || !(state.grants instanceof Map) ||
    !(state.closedTestTesters instanceof Map) || !Array.isArray(state.audits)
  ) {
    throw deny('invalid_closed_test_storage');
  }
}

function assertTesterRecord(record) {
  requireExactObject(record, TESTER_FIELDS, 'invalid_closed_test_tester_record');
  if (
    record.environment !== 'development' || record.track !== 'closed' ||
    !['active', 'revoked'].includes(record.status) || !Number.isInteger(record.revision) ||
    record.revision < 1 || record.schemaVersion !== 1
  ) {
    throw deny('invalid_closed_test_tester_record');
  }
  requireUtcInstant(record.authorizedAt, 'invalid_closed_test_tester_record');
}

function assertGrantRecord(record) {
  requireExactObject(record, GRANT_FIELDS, 'invalid_closed_test_grant_record');
  if (
    record.kind !== 'closedTestGrant' || record.track !== 'closed' ||
    !['active', 'expired'].includes(record.status) || !Number.isInteger(record.revision) ||
    record.revision < 1 || record.schemaVersion !== 1
  ) {
    throw deny('invalid_closed_test_grant_record');
  }
  requireText(record.ownerId, 'invalid_closed_test_grant_record');
  const startsAt = requireUtcInstant(record.startsAt, 'invalid_closed_test_grant_record');
  const expiresAt = requireUtcInstant(record.expiresAt, 'invalid_closed_test_grant_record');
  if (expiresAt.valueOf() - startsAt.valueOf() !== CLOSED_TEST_DURATION_MS) throw deny('invalid_closed_test_grant_record');
  requireExactObject(record.audit, ['action', 'at', 'capabilityCount', 'environment', 'revision', 'source', 'track'], 'invalid_closed_test_grant_record');
}

function requireClosedTrack(track) {
  requireText(track, 'invalid_closed_test_track');
  if (track !== 'closed') throw deny('invalid_closed_test_track');
  return track;
}

function confirmation(entitlement) {
  return Object.freeze({ status: entitlement.status, revision: entitlement.revision, requiresServerRefresh: true });
}

function sanitizedAudit({ action, track, revision, at }) {
  return Object.freeze({
    action, source: 'closedTestGrant', environment: 'development', track,
    capabilityCount: PREMIUM_CAPABILITIES.length, revision, at,
  });
}

function trustedNow(clock) {
  if (typeof clock !== 'function') throw deny('invalid_closed_test_clock');
  const now = clock();
  if (!(now instanceof Date) || Number.isNaN(now.valueOf()) || !now.toISOString().endsWith('Z')) {
    throw deny('invalid_closed_test_clock');
  }
  return now;
}
