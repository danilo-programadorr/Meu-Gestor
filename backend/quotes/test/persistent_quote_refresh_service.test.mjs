import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { PersistentQuoteRefreshService } from '../src/persistent_quote_refresh_service.mjs';

const requestId = 'request_synthetic_20260818';
const target = { ticker: 'PETR4', assetType: 'stock' };

class FakeQuoteStorage {
  constructor() {
    this.claims = new Map();
    this.snapshots = new Map();
    this.failures = new Map();
  }

  async claim({ requestId: id, target: claimed }) {
    const key = `${id}:${claimed.ticker}`;
    if (this.claims.get(key) === 'completed') return { kind: 'completed', target: claimed };
    if (this.failures.has(claimed.ticker)) return { kind: 'circuitOpen', target: claimed };
    if (this.claims.get(claimed.ticker) === 'leased') return { kind: 'leased', target: claimed };
    this.claims.set(claimed.ticker, 'leased');
    return { kind: 'claimed', target: claimed };
  }

  async complete({ requestId: id, target: completed, quote }) {
    const key = `${id}:${completed.ticker}`;
    if (this.claims.get(key) === 'completed') return { written: false, idempotent: true };
    const current = this.snapshots.get(completed.ticker);
    const written = !current || new Date(quote.observedAt) > new Date(current.observedAt);
    if (written) this.snapshots.set(completed.ticker, quote);
    this.claims.set(key, 'completed');
    this.claims.delete(completed.ticker);
    this.failures.delete(completed.ticker);
    return { written, idempotent: false };
  }

  async fail({ requestId: id, target: failed, code }) {
    this.claims.delete(failed.ticker);
    this.claims.set(`${id}:${failed.ticker}`, 'failed');
    this.failures.set(failed.ticker, code);
  }

  async read(tickers) {
    return tickers.map((ticker) => this.snapshots.get(ticker)).filter(Boolean);
  }
}

function quote(overrides = {}) {
  return {
    ticker: 'PETR4',
    currencyCode: 'BRL',
    priceScaled: 30000000,
    variationBasisPoints: 120,
    observedAt: '2026-08-18T12:00:00.000Z',
    status: 'delayed',
    declaredDelaySeconds: 900,
    staleAfter: '2026-08-18T12:30:00.000Z',
    ...overrides,
  };
}

describe('PersistentQuoteRefreshService', () => {
  test('deduplica lote, grava globalmente e repete request sem nova chamada', async () => {
    const storage = new FakeQuoteStorage();
    let calls = 0;
    const service = new PersistentQuoteRefreshService({
      storage,
      gateway: { async fetchBatch() { calls += 1; return [quote()]; } },
      clock: () => new Date('2026-08-18T12:05:00.000Z'),
    });
    const first = await service.refresh({ requestId, targets: [target, target] });
    const second = await service.refresh({ requestId, targets: [target] });
    assert.equal(calls, 1);
    assert.equal(first.length, 1);
    assert.equal(second[0].priceScaled, 30000000);
  });

  test('nunca substitui observação mais recente por resposta antiga', async () => {
    const storage = new FakeQuoteStorage();
    storage.snapshots.set('PETR4', quote({ observedAt: '2026-08-18T12:10:00.000Z', priceScaled: 31000000 }));
    const service = new PersistentQuoteRefreshService({
      storage,
      gateway: { async fetchBatch() { return [quote()]; } },
      clock: () => new Date('2026-08-18T12:15:00.000Z'),
    });
    await service.refresh({ requestId: 'request_synthetic_20260818_b', targets: [target] });
    assert.equal(storage.snapshots.get('PETR4').priceScaled, 31000000);
  });

  test('falha do provedor abre circuito sem expor dado de mercado no log', async () => {
    const storage = new FakeQuoteStorage();
    const entries = [];
    const service = new PersistentQuoteRefreshService({
      storage,
      gateway: { async fetchBatch() { const error = new Error('offline'); error.code = 'quote_provider_unavailable'; throw error; } },
      clock: () => new Date('2026-08-18T12:05:00.000Z'),
      logger: { info() {}, warn(entry) { entries.push(entry); } },
    });
    await service.refresh({ requestId, targets: [target] });
    assert.equal(storage.failures.get('PETR4'), 'quote_provider_unavailable');
    assert.deepEqual(entries, [{
      event: 'quote_refresh_failed', requestId, targetCount: 1, code: 'quote_provider_unavailable',
    }]);
  });
});
