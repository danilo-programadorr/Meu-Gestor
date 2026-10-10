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
      const normalizedQuotes = [];
      for (const item of raw) {
        const target = accepted.find((candidate) => candidate.ticker === item?.ticker);
        if (!target || received.has(target.ticker)) fail('quote_gateway_duplicate_or_unrequested');
        received.add(target.ticker);
        const capturedAt = this.clock();
        // Abertura da validação temporal: a composição não confia em
        // staleAfter fornecido por adaptadores sem revalidá-lo no domínio.
        const staleAfter = item?.staleAfter == null
            ? new Date(capturedAt.getTime() + DEFAULT_STALE_AFTER_SECONDS * 1000)
            : new Date(item.staleAfter);
        if (Number.isNaN(staleAfter.getTime())) fail('quote_gateway_invalid_stale_after');
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
          staleAfter,
        });
        normalizedQuotes.push({
          target,
          quote: quoteSnapshotDocument({
            ...quote,
            declaredDelaySeconds: Number.isInteger(item.declaredDelaySeconds)
                ? item.declaredDelaySeconds : DEFAULT_DECLARED_DELAY_SECONDS,
            staleAfter: quote.staleAfter,
          }),
        });
      }
      if (accepted.some((target) => !received.has(target.ticker))) {
        fail('quote_provider_missing_ticker');
      }
      for (const normalized of normalizedQuotes) {
        await this.storage.complete({
          requestId: normalizedRequestId,
          target: normalized.target,
          quote: normalized.quote,
          now: this.clock(),
        });
      }
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
      throw safeFailure(code);
    }
    this.logger.info({ event: 'quote_refresh_completed', requestId: normalizedRequestId, targetCount: accepted.length });
    return this.storage.read(normalizedTargets.map((target) => target.ticker));
  }
}

function safeFailure(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

function safeErrorCode(error) {
  return typeof error?.code === 'string' && /^[a-z0-9_]{3,80}$/.test(error.code)
      ? error.code : 'quote_refresh_failed';
}
