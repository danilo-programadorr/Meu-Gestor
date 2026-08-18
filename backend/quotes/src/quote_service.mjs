import { mapProviderQuote, QuoteStatus } from './quote_mapper.mjs';

/// Global ticker cache. There is deliberately no user or portfolio parameter.
export class QuoteService {
  constructor({ gateway, clock, staleAfterMs = 20 * 60 * 1000, cooldownMs = 60 * 1000 }) {
    this.gateway = gateway;
    this.clock = clock;
    this.staleAfterMs = staleAfterMs;
    this.cooldownMs = cooldownMs;
    this.snapshots = new Map();
    this.leases = new Map();
    this.failures = new Map();
  }

  async refresh(tickers) {
    const unique = [...new Set(tickers)].sort();
    if (unique.length === 0) return [];
    if (unique.some((ticker) => typeof ticker !== 'string' || !/^[A-Z]{4}[0-9]{1,2}$/.test(ticker))) {
      throw new Error('quote_invalid_ticker_batch');
    }
    const now = this.clock();
    const eligible = unique.filter((ticker) => !this.#onCooldown(ticker, now) && !this.leases.has(ticker));
    if (eligible.length === 0) return this.read(unique);
    const lease = Symbol('quote-lease');
    eligible.forEach((ticker) => this.leases.set(ticker, lease));
    try {
      const raw = await this.gateway.fetchBatch(eligible);
      if (!Array.isArray(raw)) throw new Error('quote_gateway_invalid_batch');
      const received = new Set();
      for (const item of raw) {
        const capturedAt = this.clock();
        const mapped = mapProviderQuote(item, {
          capturedAt,
          staleAfter: new Date(capturedAt.getTime() + this.staleAfterMs),
        });
        if (!eligible.includes(mapped.ticker) || received.has(mapped.ticker)) throw new Error('quote_gateway_duplicate_or_unrequested');
        received.add(mapped.ticker);
        const current = this.snapshots.get(mapped.ticker);
        if (!current || new Date(mapped.observedAt) > new Date(current.observedAt)) {
          this.snapshots.set(mapped.ticker, mapped);
        }
        this.failures.delete(mapped.ticker);
      }
      return this.read(unique);
    } catch (error) {
      eligible.forEach((ticker) => this.failures.set(ticker, now.getTime()));
      return this.read(unique);
    } finally {
      eligible.forEach((ticker) => {
        if (this.leases.get(ticker) === lease) this.leases.delete(ticker);
      });
    }
  }

  read(tickers) {
    return [...new Set(tickers)].sort().map((ticker) => this.snapshots.get(ticker) ?? Object.freeze({
      ticker,
      assetType: null,
      currencyCode: 'BRL',
      priceScaled: 0,
      variationBasisPoints: null,
      observedAt: null,
      capturedAt: null,
      staleAfter: null,
      status: QuoteStatus.UNAVAILABLE,
    }));
  }

  #onCooldown(ticker, now) {
    const failure = this.failures.get(ticker);
    return failure !== undefined && now.getTime() - failure < this.cooldownMs;
  }
}
