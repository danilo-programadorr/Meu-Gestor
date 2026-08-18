export const QUOTE_COLLECTIONS = Object.freeze({
  snapshots: 'marketQuoteSnapshots',
  leases: '_marketQuoteLeases',
  requests: '_marketQuoteRefreshRequests',
  circuits: '_marketQuoteCircuitBreakers',
});

export const QUOTE_SCHEMA_VERSION = 1;
export const QUOTE_MARKET = 'B3';
export const QUOTE_SOURCE = 'brapi';
export const MAX_BATCH_SIZE = 50;
export const DEFAULT_DECLARED_DELAY_SECONDS = 15 * 60;
export const DEFAULT_STALE_AFTER_SECONDS = 30 * 60;

const tickerExpression = /^[A-Z]{4}[0-9]{1,2}$/;

export function requireTicker(value) {
  if (typeof value !== 'string' || !tickerExpression.test(value)) {
    fail('quote_invalid_ticker');
  }
  return value;
}

export function requireRefreshRequest(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{16,96}$/.test(value)) {
    fail('quote_invalid_refresh_request');
  }
  return value;
}

export function normalizeTargets(targets) {
  if (!Array.isArray(targets) || targets.length === 0 || targets.length > MAX_BATCH_SIZE) {
    fail('quote_invalid_target_batch');
  }
  const normalized = new Map();
  for (const target of targets) {
    if (!target || typeof target !== 'object' || Array.isArray(target)) {
      fail('quote_invalid_target');
    }
    const keys = Object.keys(target).sort();
    const expected = ['assetType', 'ticker'];
    if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) {
      fail('quote_invalid_target');
    }
    const ticker = requireTicker(target.ticker);
    if (!['stock', 'fii'].includes(target.assetType)) {
      fail('quote_invalid_asset_type');
    }
    const existing = normalized.get(ticker);
    if (existing && existing.assetType !== target.assetType) {
      fail('quote_conflicting_target_type');
    }
    normalized.set(ticker, Object.freeze({ ticker, assetType: target.assetType }));
  }
  return Object.freeze([...normalized.values()].sort((first, second) => first.ticker.localeCompare(second.ticker)));
}

export function quoteSnapshotDocument(quote) {
  return Object.freeze({
    ticker: quote.ticker,
    assetType: quote.assetType,
    currencyCode: 'BRL',
    market: QUOTE_MARKET,
    source: QUOTE_SOURCE,
    priceScaled: quote.priceScaled,
    variationBasisPoints: quote.variationBasisPoints,
    observedAt: quote.observedAt,
    capturedAt: quote.capturedAt,
    declaredDelaySeconds: quote.declaredDelaySeconds,
    staleAfter: quote.staleAfter,
    status: quote.status,
    schemaVersion: QUOTE_SCHEMA_VERSION,
  });
}

export function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
