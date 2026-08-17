import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';
import {
  planIdForBasePlan,
  resolvePremiumGooglePlayCatalog,
  validatePremiumOffer,
  validatePremiumTrialPeriod,
} from './catalog.mjs';

export const PREMIUM_CAPABILITIES = Object.freeze([
  'investmentsManual',
  'investmentIncome',
  'investmentQuotes',
  'investmentCalculators',
  'investmentAnalysis',
]);

const RESPONSE_FIELDS = Object.freeze([
  'eventId', 'eventTime', 'packageName', 'subscriptionId', 'basePlanId', 'offerId',
  'subscriptionState', 'periodStart', 'periodEnd', 'graceUntil',
  'autoRenewEnabled', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt',
  'acknowledgementState', 'linkedPurchaseToken', 'obfuscatedExternalAccountId',
]);

const EXPECTED_FIELDS = Object.freeze([
  'packageName', 'environment', 'obfuscatedAccountId', 'catalog',
]);

const STATUS = Object.freeze({
  PENDING: 'pending', TRIALING: 'trialing', ACTIVE: 'active',
  IN_GRACE_PERIOD: 'gracePeriod', ON_HOLD: 'accountHold', PAUSED: 'paused',
  CANCELLED: 'cancelled', EXPIRED: 'expired', REVOKED: 'revoked', REFUNDED: 'refunded',
});

export function mapGooglePlaySubscription(raw, expected) {
  requireExactObject(expected, EXPECTED_FIELDS, 'invalid_google_play_expectation');
  requireText(expected.packageName, 'invalid_expected_package_name');
  requireText(expected.environment, 'invalid_expected_environment');
  if (!['development', 'production'].includes(expected.environment)) throw deny('invalid_expected_environment');
  requireText(expected.obfuscatedAccountId, 'invalid_expected_obfuscated_account_id');
  const catalog = resolvePremiumGooglePlayCatalog(expected.catalog);
  requireExactObject(raw, RESPONSE_FIELDS, 'invalid_google_play_response_shape');
  for (const field of ['eventId', 'packageName', 'subscriptionId', 'basePlanId', 'subscriptionState', 'acknowledgementState', 'obfuscatedExternalAccountId']) {
    requireText(raw[field], `invalid_${field}`);
  }
  if (
    raw.packageName !== expected.packageName ||
    raw.subscriptionId !== catalog.subscriptionId ||
    raw.obfuscatedExternalAccountId !== expected.obfuscatedAccountId
  ) {
    throw deny('purchase_identity_mismatch');
  }
  const status = STATUS[raw.subscriptionState];
  if (!status) throw deny('unknown_subscription_state');
  const planId = planIdForBasePlan(raw.basePlanId);
  const offerId = validatePremiumOffer({ basePlanId: raw.basePlanId, offerId: raw.offerId, status });
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
  const cancellationMayBePreserved = status === 'cancelled' || status === 'expired';
  if (
    (status === 'cancelled' && cancelledAt === null) ||
    (!cancellationMayBePreserved && cancelledAt !== null) ||
    (cancelledAt !== null && raw.autoRenewEnabled)
  ) {
    throw deny('invalid_cancellation_state');
  }
  if ((status === 'expired') !== (expiredAt !== null) || (status === 'revoked') !== (revokedAt !== null) ||
      (status === 'refunded') !== (refundedAt !== null)) throw deny('invalid_terminal_state');
  for (const lifecycleDate of [cancelledAt, expiredAt, revokedAt, refundedAt].filter(Boolean)) {
    if (lifecycleDate < periodStart || lifecycleDate > eventTime) throw deny('invalid_lifecycle_timestamp');
  }
  if (expiredAt && expiredAt < periodEnd) throw deny('expiration_before_period_end');
  validatePremiumTrialPeriod({ offerId, status, periodStart, periodEnd });
  const startedAt = periodStart?.toISOString() ?? null;
  return Object.freeze({
    eventId: raw.eventId,
    eventTime: eventTime.toISOString(),
    subscriptionId: raw.subscriptionId,
    basePlanId: raw.basePlanId,
    offerId,
    planId,
    status,
    source: 'googlePlay',
    environment: expected.environment,
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
