import { deny } from './errors.mjs';

const TERMINAL_STATUSES = new Set(['revoked', 'refunded']);
const NEW_PURCHASE_CYCLE_TARGETS = new Set(['pending', 'trialing', 'active']);

const ALLOWED_TARGETS = Object.freeze({
  pending: new Set(['trialing', 'active', 'revoked']),
  trialing: new Set(['active', 'gracePeriod', 'accountHold', 'paused', 'cancelled', 'expired', 'revoked']),
  active: new Set(['active', 'gracePeriod', 'accountHold', 'paused', 'cancelled', 'expired', 'revoked', 'refunded']),
  gracePeriod: new Set(['gracePeriod', 'active', 'accountHold', 'cancelled', 'expired', 'revoked', 'refunded']),
  accountHold: new Set(['active', 'paused', 'cancelled', 'expired', 'revoked', 'refunded']),
  paused: new Set(['active', 'cancelled', 'expired', 'revoked', 'refunded']),
  cancelled: new Set(['active', 'gracePeriod', 'accountHold', 'paused', 'expired', 'revoked', 'refunded']),
  expired: new Set(['trialing', 'active', 'revoked', 'refunded']),
  revoked: new Set(),
  refunded: new Set(),
});

export function assertSubscriptionTransition({ current, next, isNewPurchaseCycle }) {
  if (typeof isNewPurchaseCycle !== 'boolean') throw deny('invalid_subscription_cycle_identity');
  const changesSource = current.source !== next.source;
  const permittedNewPurchaseSource = current.source === 'developmentGrant' && next.source === 'googlePlay';
  if (changesSource && !(isNewPurchaseCycle && permittedNewPurchaseSource)) {
    throw deny('subscription_source_transition_denied');
  }
  if (TERMINAL_STATUSES.has(current.status)) {
    if (isNewPurchaseCycle) {
      assertNewPurchaseCycle(current, next);
      return;
    }
    throw deny('subscription_terminal_transition_denied');
  }
  if (current.status === 'expired' && NEW_PURCHASE_CYCLE_TARGETS.has(next.status)) {
    if (!isNewPurchaseCycle) throw deny('subscription_expired_cycle_denied');
    assertNewPurchaseCycle(current, next);
    return;
  }
  if (isNewPurchaseCycle && permittedNewPurchaseSource) {
    assertNewPurchaseCycle(current, next);
    return;
  }
  const allowedTargets = ALLOWED_TARGETS[current.status];
  if (!allowedTargets || !allowedTargets.has(next.status)) {
    throw deny('unsupported_subscription_transition');
  }
  assertPeriodMonotonicity(current, next, isNewPurchaseCycle);
  if (current.status === next.status) {
    if (
      typeof current.currentPeriodEnd !== 'string' ||
      typeof next.currentPeriodEnd !== 'string' ||
      next.currentPeriodEnd <= current.currentPeriodEnd
    ) {
      throw deny('subscription_period_regression');
    }
    return;
  }
  if (
    next.status === 'active' &&
    typeof current.currentPeriodEnd === 'string' &&
    typeof next.currentPeriodEnd === 'string' &&
    next.currentPeriodEnd > current.currentPeriodEnd
  ) {
    return;
  }
}

function assertNewPurchaseCycle(current, next) {
  if (!NEW_PURCHASE_CYCLE_TARGETS.has(next.status)) {
    throw deny('subscription_new_cycle_status_denied');
  }
  if (next.status === 'pending') return;
  const endedAt = current.status === 'expired'
    ? current.expiredAt
    : current.revokedAt ?? current.refundedAt;
  if (
    (current.status === 'expired' || TERMINAL_STATUSES.has(current.status)) &&
    (typeof endedAt !== 'string' ||
    typeof next.currentPeriodStart !== 'string' ||
    next.currentPeriodStart < endedAt)
  ) {
    throw deny('subscription_new_cycle_period_denied');
  }
}

function assertPeriodMonotonicity(current, next, isNewPurchaseCycle) {
  if (
    typeof current.currentPeriodEnd === 'string' &&
    typeof next.currentPeriodEnd === 'string' &&
    next.currentPeriodEnd < current.currentPeriodEnd &&
    !TERMINAL_STATUSES.has(next.status)
  ) {
    throw deny('subscription_period_regression');
  }
  if (
    !isNewPurchaseCycle &&
    typeof current.currentPeriodStart === 'string' &&
    typeof next.currentPeriodStart === 'string' &&
    next.currentPeriodStart < current.currentPeriodStart
  ) {
    throw deny('subscription_period_regression');
  }
}
