import { mapProviderQuote } from './quote_mapper.mjs';
import {
  DEFAULT_DECLARED_DELAY_SECONDS,
  DEFAULT_STALE_AFTER_SECONDS,
  fail,
  normalizeTargets,
  quoteSnapshotDocument,
  requireRefreshRequest,
} from './quote_contract.mjs';

const leaseDurationMs = 90 * 1000;
const initialCircuitDelayMs = 60 * 1000;
const maximumCircuitDelayMs = 60 * 60 * 1000;

/// Orquestrador provider-neutral. O armazenamento é global por ticker e não
/// recebe UID, carteira ou outra informação financeira individual.
export class PersistentQuoteRefreshService {
  constructor({ storage, gateway, clock, logger = { info() {}, warn() {} } }) {
    if (!storage || typeof storage.claim !== 'function' || typeof storage.complete !== 'function' ||
        typeof storage.fail !== 'function' || typeof storage.read !== 'function' ||
        !gateway || typeof gateway.fetchBatch !== 'function' || typeof clock !== 'function') {
      throw new TypeError('quote_invalid_refresh_dependencies');
    }
    this.storage = storage;
    this.gateway = gateway;
    this.clock = clock;
    this.logger = logger;
  }

  async refresh({ requestId, targets }) {
    const normalizedRequestId = requireRefreshRequest(requestId);
    const normalizedTargets = normalizeTargets(targets);
    const now = this.clock();
    const claims = await Promise.all(normalizedTargets.map((target) => this.storage.claim({
      requestId: normalizedRequestId,
      target,
      now,
      leaseExpiresAt: new Date(now.getTime() + leaseDurationMs),
    })));
    const accepted = claims.filter((claim) => claim.kind === 'claimed').map((claim) => claim.target);
    if (accepted.length === 0) {
      return this.storage.read(normalizedTargets.map((target) => target.ticker));
    }
    try {
      const raw = await this.gateway.fetchBatch(accepted);
      if (!Array.isArray(raw)) fail('quote_gateway_invalid_batch');
      const received = new Set();
      for (const item of raw) {
        const target = accepted.find((candidate) => candidate.ticker === item?.ticker);
        if (!target || received.has(target.ticker)) fail('quote_gateway_duplicate_or_unrequested');
        received.add(target.ticker);
        const capturedAt = this.clock();
        const quote = mapProviderQuote({
          ticker: item.ticker,
          assetType: target.assetType,
          currencyCode: item.currencyCode,
          priceScaled: item.priceScaled,
          variationBasisPoints: item.variationBasisPoints,
          observedAt: item.observedAt,
          status: item.status,
        }, {
          capturedAt,
          staleAfter: new Date(capturedAt.getTime() + DEFAULT_STALE_AFTER_SECONDS * 1000),
        });
        await this.storage.complete({
          requestId: normalizedRequestId,
          target,
          quote: quoteSnapshotDocument({
            ...quote,
            declaredDelaySeconds: Number.isInteger(item.declaredDelaySeconds)
                ? item.declaredDelaySeconds : DEFAULT_DECLARED_DELAY_SECONDS,
            staleAfter: item.staleAfter ?? quote.staleAfter,
          }),
          now: this.clock(),
        });
      }
      for (const target of accepted.filter((target) => !received.has(target.ticker))) {
        await this.storage.fail({ requestId: normalizedRequestId, target, now: this.clock(), code: 'quote_provider_missing_ticker' });
      }
      this.logger.info({ event: 'quote_refresh_completed', requestId: normalizedRequestId, targetCount: accepted.length });
    } catch (error) {
      const code = safeErrorCode(error);
      await Promise.all(accepted.map((target) => this.storage.fail({
        requestId: normalizedRequestId,
        target,
        now: this.clock(),
        code,
        nextRetryAt: new Date(this.clock().getTime() + initialCircuitDelayMs),
        maximumCircuitDelayMs,
      })));
      this.logger.warn({ event: 'quote_refresh_failed', requestId: normalizedRequestId, targetCount: accepted.length, code });
    }
    return this.storage.read(normalizedTargets.map((target) => target.ticker));
  }
}

function safeErrorCode(error) {
  return typeof error?.code === 'string' && /^[a-z0-9_]{3,80}$/.test(error.code)
      ? error.code : 'quote_refresh_failed';
}
