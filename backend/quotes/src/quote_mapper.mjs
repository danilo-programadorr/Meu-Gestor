const TICKER = /^[A-Z]{4}[0-9]{1,2}$/;
const MAX_PRICE_SCALED = 999999999999;

export const QuoteStatus = Object.freeze({
  AVAILABLE: 'available',
  DELAYED: 'delayed',
  MARKET_CLOSED: 'marketClosed',
  UNAVAILABLE: 'unavailable',
  INVALID: 'invalid',
  CORPORATE_ACTION_POSSIBLE: 'corporateActionPossible',
});

const pricedStatuses = new Set([
  QuoteStatus.AVAILABLE,
  QuoteStatus.DELAYED,
  QuoteStatus.MARKET_CLOSED,
]);
const statuses = new Set(Object.values(QuoteStatus));

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}

/// Maps only a normalized provider response. It never accepts a user id,
/// client timestamp, currency other than BRL or a zero/negative price.
export function mapProviderQuote(input, { capturedAt, staleAfter }) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail('quote_invalid_shape');
  const keys = Object.keys(input).sort();
  const expected = ['assetType', 'currencyCode', 'observedAt', 'priceScaled', 'status', 'ticker', 'variationBasisPoints'];
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) {
    fail('quote_extra_or_missing_field');
  }
  if (typeof input.ticker !== 'string' || !TICKER.test(input.ticker) ||
      !['stock', 'fii'].includes(input.assetType) || input.currencyCode !== 'BRL' || !statuses.has(input.status) ||
      typeof input.observedAt !== 'string') fail('quote_invalid_identity');
  const observedAt = new Date(input.observedAt);
  if (Number.isNaN(observedAt.getTime()) || observedAt > capturedAt) fail('quote_invalid_observed_at');
  if (!Number.isInteger(input.priceScaled) || input.priceScaled < 0 || input.priceScaled > MAX_PRICE_SCALED) {
    fail('quote_invalid_price');
  }
  const priced = pricedStatuses.has(input.status);
  if ((priced && (!Number.isInteger(input.variationBasisPoints) || input.priceScaled === 0)) ||
      (!priced && (input.priceScaled !== 0 || input.variationBasisPoints !== null))) {
    fail('quote_status_price_mismatch');
  }
  if (!(staleAfter instanceof Date) || staleAfter <= capturedAt) fail('quote_invalid_stale_after');
  return Object.freeze({
    ticker: input.ticker,
    assetType: input.assetType,
    currencyCode: input.currencyCode,
    priceScaled: input.priceScaled,
    variationBasisPoints: input.variationBasisPoints,
    observedAt: observedAt.toISOString(),
    capturedAt: capturedAt.toISOString(),
    staleAfter: staleAfter.toISOString(),
    status: input.status,
  });
}
