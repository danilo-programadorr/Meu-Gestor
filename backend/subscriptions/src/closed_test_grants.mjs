import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';
import { PREMIUM_CAPABILITIES } from './mapper.mjs';

export const CLOSED_TEST_DURATION_MS = 15 * 24 * 60 * 60 * 1000;
const REQUEST_FIELDS = Object.freeze(['grantId', 'ownerId', 'track']);
const WINDOW_FIELDS = Object.freeze(['environment', 'track', 'startsAt', 'expiresAt']);

/// Emite somente no backend futuro. Não recebe ator, preço, capabilities ou
/// prazo do aplicativo; a lista autorizada e a janela pertencem ao servidor.
export async function issueClosedTestGrant({ request, window, authorizedOwnerIds, storage, clock }) {
  requireExactObject(request, REQUEST_FIELDS, 'invalid_closed_test_grant_request');
  for (const field of REQUEST_FIELDS) requireText(request[field], `invalid_closed_test_grant_${field}`);
  const configured = resolveClosedTestWindow(window);
  if (!(authorizedOwnerIds instanceof Set) || !authorizedOwnerIds.has(request.ownerId)) {
    throw deny('closed_test_tester_not_authorized');
  }
  if (request.track !== configured.track) throw deny('closed_test_track_mismatch');
  const now = trustedNow(clock);
  if (now < configured.startsAt || now >= configured.expiresAt) throw deny('closed_test_window_closed');
  return storage.transaction((state) => {
    const previous = state.grants.get(request.grantId);
    if (previous) {
      if (previous.request.ownerId !== request.ownerId || previous.request.track !== request.track) {
        throw deny('closed_test_grant_id_conflict');
      }
      return previous.confirmation;
    }
    const current = state.entitlements.get(request.ownerId);
    if (current && current.environment !== 'development') throw deny('closed_test_environment_conflict');
    const nowText = now.toISOString();
    const projection = {
      ownerId: request.ownerId, planId: 'monthly', status: 'active', source: 'closedTestGrant',
      environment: 'development', capabilities: [...PREMIUM_CAPABILITIES],
      startedAt: configured.startsAt.toISOString(), currentPeriodStart: configured.startsAt.toISOString(),
      currentPeriodEnd: configured.expiresAt.toISOString(), graceUntil: null,
      cancelAtPeriodEnd: false, cancelledAt: null, expiredAt: null, revokedAt: null, refundedAt: null,
      lastVerifiedAt: nowText, revision: (current?.revision ?? 0) + 1, schemaVersion: 1,
      createdAt: current?.createdAt ?? nowText, updatedAt: nowText,
    };
    state.entitlements.set(request.ownerId, projection);
    const confirmation = { status: 'active', revision: projection.revision, requiresServerRefresh: true };
    state.grants.set(request.grantId, { request: { ownerId: request.ownerId, track: request.track }, confirmation, kind: 'closedTestGrant' });
    state.audits.push({ action: 'issued', source: 'closedTestGrant', environment: 'development', track: request.track, capabilityCount: 5, revision: projection.revision, at: nowText });
    return confirmation;
  });
}

/// O backend futuro chama esta rotina com relógio confiável para materializar
/// a expiração global; o aplicativo nunca calcula os quinze dias localmente.
export async function expireClosedTestGrants({ window, storage, clock }) {
  const configured = resolveClosedTestWindow(window);
  const now = trustedNow(clock);
  if (now < configured.expiresAt) return Object.freeze({ expired: 0 });
  return storage.transaction((state) => {
    let expired = 0;
    for (const [ownerId, entitlement] of state.entitlements) {
      if (entitlement.source !== 'closedTestGrant' || entitlement.status !== 'active') continue;
      state.entitlements.set(ownerId, { ...entitlement, status: 'expired', capabilities: [], expiredAt: configured.expiresAt.toISOString(), lastVerifiedAt: now.toISOString(), updatedAt: now.toISOString(), revision: entitlement.revision + 1 });
      expired += 1;
    }
    return Object.freeze({ expired });
  });
}

export function resolveClosedTestWindow(window) {
  requireExactObject(window, WINDOW_FIELDS, 'invalid_closed_test_window');
  if (window.environment !== 'development') throw deny('closed_test_production_denied');
  requireText(window.track, 'invalid_closed_test_track');
  if (window.track !== 'closed') throw deny('invalid_closed_test_track');
  const startsAt = requireUtcInstant(window.startsAt, 'invalid_closed_test_start');
  const expiresAt = requireUtcInstant(window.expiresAt, 'invalid_closed_test_expiration');
  if (expiresAt.valueOf() - startsAt.valueOf() !== CLOSED_TEST_DURATION_MS) throw deny('invalid_closed_test_duration');
  return Object.freeze({ environment: 'development', track: window.track, startsAt, expiresAt });
}

function trustedNow(clock) {
  if (typeof clock !== 'function') throw deny('invalid_closed_test_clock');
  const now = clock();
  if (!(now instanceof Date) || Number.isNaN(now.valueOf()) || !now.toISOString().endsWith('Z')) throw deny('invalid_closed_test_clock');
  return now;
}
