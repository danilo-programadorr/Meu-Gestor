import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';
import { PREMIUM_CAPABILITIES } from './mapper.mjs';

const FIELDS = Object.freeze(['grantId', 'actorId', 'ownerId', 'reason', 'environment', 'source', 'planId', 'validFrom', 'validUntil', 'capabilities']);

export async function applyAdministrativeGrant({ request, storage, clock }) {
  requireExactObject(request, FIELDS, 'invalid_grant_shape');
  for (const field of ['grantId', 'actorId', 'ownerId', 'reason', 'environment', 'source', 'planId']) requireText(request[field], `invalid_grant_${field}`);
  if (request.ownerId !== request.actorId || !['administrativeGrant', 'developmentGrant'].includes(request.source)) throw deny('grant_actor_denied');
  if (request.source === 'developmentGrant' && request.environment !== 'development') throw deny('development_grant_in_production');
  if (!['monthly', 'annual'].includes(request.planId) || !Array.isArray(request.capabilities) ||
      request.capabilities.some((item) => !PREMIUM_CAPABILITIES.includes(item)) || new Set(request.capabilities).size !== request.capabilities.length) throw deny('invalid_grant_scope');
  const validFrom = requireUtcInstant(request.validFrom, 'invalid_grant_start');
  const validUntil = requireUtcInstant(request.validUntil, 'invalid_grant_end');
  if (validFrom >= validUntil) throw deny('invalid_grant_period');
  return storage.transaction((state) => {
    const prior = state.grants.get(request.grantId);
    if (prior) {
      if (JSON.stringify(prior.request) !== JSON.stringify(request)) throw deny('grant_id_conflict');
      return prior.confirmation;
    }
    const current = state.entitlements.get(request.ownerId);
    const now = clock().toISOString();
    const projection = {
      ownerId: request.ownerId, planId: request.planId, status: 'active', source: request.source,
      environment: request.environment, capabilities: [...request.capabilities], startedAt: request.validFrom,
      currentPeriodStart: request.validFrom, currentPeriodEnd: request.validUntil, graceUntil: null,
      cancelAtPeriodEnd: false, cancelledAt: null, expiredAt: null, revokedAt: null, refundedAt: null,
      lastVerifiedAt: now, revision: (current?.revision ?? 0) + 1, schemaVersion: 1,
      createdAt: current?.createdAt ?? now, updatedAt: now,
    };
    state.entitlements.set(request.ownerId, projection);
    const confirmation = { ownerId: request.ownerId, status: 'active', revision: projection.revision, requiresServerRefresh: true };
    state.grants.set(request.grantId, { request: structuredClone(request), confirmation, revoked: false });
    return confirmation;
  });
}

export async function revokeAdministrativeGrant({ grantId, actorId, ownerId, reason, storage, clock }) {
  for (const value of [grantId, actorId, ownerId, reason]) requireText(value, 'invalid_grant_revocation');
  if (actorId !== ownerId) throw deny('grant_actor_denied');
  return storage.transaction((state) => {
    const grant = state.grants.get(grantId);
    if (!grant || grant.request.ownerId !== ownerId) throw deny('grant_not_found');
    if (grant.revoked) return grant.revokeConfirmation;
    const current = state.entitlements.get(ownerId);
    const now = clock().toISOString();
    const projection = { ...current, status: 'revoked', capabilities: [], revokedAt: now, lastVerifiedAt: now, updatedAt: now, revision: current.revision + 1 };
    state.entitlements.set(ownerId, projection);
    grant.revoked = true;
    grant.revocationReason = reason;
    grant.revokeConfirmation = { ownerId, status: 'revoked', revision: projection.revision, requiresServerRefresh: true };
    return grant.revokeConfirmation;
  });
}
