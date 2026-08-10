import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';

export const PREMIUM_CAPABILITIES = Object.freeze([
  'investmentsManual',
  'investmentIncome',
  'investmentQuotes',
  'investmentCalculators',
  'investmentAnalysis',
]);

const RESPONSE_FIELDS = Object.freeze([
  'eventId', 'eventTime', 'packageName', 'productId', 'environment',
  'subscriptionState', 'periodStart', 'periodEnd', 'graceUntil',
  'autoRenewEnabled', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt',
  'acknowledgementState', 'linkedPurchaseToken', 'obfuscatedExternalAccountId',
]);

const STATUS = Object.freeze({
  PENDING: 'pending', TRIALING: 'trialing', ACTIVE: 'active',
  IN_GRACE_PERIOD: 'gracePeriod', ON_HOLD: 'accountHold', PAUSED: 'paused',
  CANCELLED: 'cancelled', EXPIRED: 'expired', REVOKED: 'revoked', REFUNDED: 'refunded',
});

export function mapGooglePlaySubscription(raw, expected) {
  requireExactObject(raw, RESPONSE_FIELDS, 'invalid_google_play_response_shape');
  for (const field of ['eventId', 'packageName', 'productId', 'environment', 'subscriptionState', 'acknowledgementState', 'obfuscatedExternalAccountId']) {
    requireText(raw[field], `invalid_${field}`);
  }
  if (raw.packageName !== expected.packageName || raw.productId !== expected.productId ||
      raw.environment !== expected.environment || raw.obfuscatedExternalAccountId !== expected.obfuscatedAccountId) {
    throw deny('purchase_identity_mismatch');
  }
  if (!expected.allowedProducts.has(raw.productId)) throw deny('product_not_allowed');
  const status = STATUS[raw.subscriptionState];
  if (!status) throw deny('unknown_subscription_state');
  if (!['PENDING', 'ACKNOWLEDGED'].includes(raw.acknowledgementState)) throw deny('unknown_acknowledgement_state');
  if (typeof raw.autoRenewEnabled !== 'boolean') throw deny('invalid_auto_renew_state');
  const eventTime = requireUtcInstant(raw.eventTime, 'invalid_event_time');
  const periodStart = requireUtcInstant(raw.periodStart, 'invalid_period_start', true);
  const periodEnd = requireUtcInstant(raw.periodEnd, 'invalid_period_end', true);
  const graceUntil = requireUtcInstant(raw.graceUntil, 'invalid_grace_until', true);
  const cancelledAt = requireUtcInstant(raw.cancelledAt, 'invalid_cancelled_at', true);
  const expiredAt = requireUtcInstant(raw.expiredAt, 'invalid_expired_at', true);
  const revokedAt = requireUtcInstant(raw.revokedAt, 'invalid_revoked_at', true);
  const refundedAt = requireUtcInstant(raw.refundedAt, 'invalid_refunded_at', true);
  const linkedPurchaseToken = raw.linkedPurchaseToken === null ? null : requireText(raw.linkedPurchaseToken, 'invalid_linked_purchase_token', 4096);
  const needsPeriod = status !== 'pending';
  if (needsPeriod !== (periodStart !== null && periodEnd !== null) ||
      (periodStart && periodEnd && periodStart >= periodEnd)) throw deny('invalid_subscription_period');
  if (periodStart && eventTime < periodStart) throw deny('verification_before_subscription_period');
  if ((status === 'gracePeriod') !== (graceUntil !== null) || (graceUntil && graceUntil <= periodEnd)) throw deny('invalid_grace_period');
  if ((status === 'cancelled') !== (cancelledAt !== null) || (status === 'cancelled' && raw.autoRenewEnabled)) throw deny('invalid_cancellation_state');
  if ((status === 'expired') !== (expiredAt !== null) || (status === 'revoked') !== (revokedAt !== null) ||
      (status === 'refunded') !== (refundedAt !== null)) throw deny('invalid_terminal_state');
  for (const lifecycleDate of [cancelledAt, expiredAt, revokedAt, refundedAt].filter(Boolean)) {
    if (lifecycleDate < periodStart || lifecycleDate > eventTime) throw deny('invalid_lifecycle_timestamp');
  }
  if (expiredAt && expiredAt < periodEnd) throw deny('expiration_before_period_end');
  const planId = raw.productId.endsWith('_annual') ? 'annual' : raw.productId.endsWith('_monthly') ? 'monthly' : null;
  if (!planId) throw deny('unmapped_product');
  const startedAt = periodStart?.toISOString() ?? null;
  return Object.freeze({
    eventId: raw.eventId,
    eventTime: eventTime.toISOString(),
    productId: raw.productId,
    planId,
    status,
    source: 'googlePlay',
    environment: raw.environment,
    capabilities: status === 'pending' ? [] : [...PREMIUM_CAPABILITIES],
    startedAt,
    currentPeriodStart: startedAt,
    currentPeriodEnd: periodEnd?.toISOString() ?? null,
    graceUntil: graceUntil?.toISOString() ?? null,
    cancelAtPeriodEnd: cancelledAt !== null,
    cancelledAt: cancelledAt?.toISOString() ?? null,
    expiredAt: expiredAt?.toISOString() ?? null,
    revokedAt: revokedAt?.toISOString() ?? null,
    refundedAt: refundedAt?.toISOString() ?? null,
    acknowledged: raw.acknowledgementState === 'ACKNOWLEDGED',
    linkedPurchaseToken,
  });
}
