import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { BrapiDelayedQuoteGateway, mapBrapiPayload } from '../src/brapi_gateway.mjs';

const capturedAt = new Date('2026-08-18T15:00:00.000Z');
const targets = [{ ticker: 'PETR4', assetType: 'stock' }, { ticker: 'HGLG11', assetType: 'fii' }];

function payload(overrides = {}) {
  return {
    results: [{
      symbol: 'PETR4',
      regularMarketPrice: 31.45,
      regularMarketChangePercent: -1.23,
      regularMarketTime: '2026-08-18T14:45:00.000Z',
      marketState: 'REGULAR',
      ...overrides,
    }],
  };
}

describe('BRAPI delayed quote adapter', () => {
  test('normaliza preço e variação para inteiros escalados sem persistir token', () => {
    const [quote] = mapBrapiPayload({ payload: payload(), targets, capturedAt });
    assert.equal(quote.priceScaled, 31450000);
    assert.equal(quote.variationBasisPoints, -123);
    assert.equal(quote.status, 'delayed');
    assert.equal(quote.observedAt, '2026-08-18T14:45:00.000Z');
  });

  test('reporta mercado fechado e recusa preço, tempo ou ticker inválidos', () => {
    const [closed] = mapBrapiPayload({
      payload: payload({ marketState: 'CLOSED' }), targets, capturedAt,
    });
    assert.equal(closed.status, 'marketClosed');
    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketPrice: 0 }), targets, capturedAt,
    }), { message: 'quote_provider_invalid_price' });
    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-19T00:00:00.000Z' }), targets, capturedAt,
    }), { message: 'quote_provider_invalid_observed_at' });
    assert.throws(() => mapBrapiPayload({
      payload: payload({ symbol: 'UNKN3' }), targets, capturedAt,
    }), { message: 'quote_provider_unexpected_result' });
  });

  test('não chama sandbox sem token configurado', async () => {
    const gateway = new BrapiDelayedQuoteGateway({
      token: () => null,
      clock: () => capturedAt,
      fetchImpl: () => { throw new Error('network must not be called'); },
    });
    await assert.rejects(
      gateway.fetchBatch([{ ticker: 'PETR4', assetType: 'stock' }]),
      { message: 'quote_provider_not_configured' },
    );
  });

  test('plano gratuito rejeita mais de um ticker antes de chamar o provedor', async () => {
    let called = false;
    const gateway = new BrapiDelayedQuoteGateway({
      token: () => 'synthetic-token',
      clock: () => capturedAt,
      fetchImpl: async () => { called = true; },
    });
    await assert.rejects(gateway.fetchBatch(targets), {
      message: 'quote_provider_plan_limit_exceeded',
    });
    assert.equal(called, false);
  });

  test('envia lote limitado com timeout e não aceita falha de transporte', async () => {
    let received;
    const gateway = new BrapiDelayedQuoteGateway({
      token: () => 'synthetic-token',
      clock: () => capturedAt,
      fetchImpl: async (url, options) => {
        received = { url, options };
        return { ok: true, json: async () => payload() };
      },
    });
    await gateway.fetchBatch([{ ticker: 'PETR4', assetType: 'stock' }]);
    assert.equal(received.url.hostname, 'brapi.dev');
    assert.equal(received.url.searchParams.get('range'), '1d');
    assert.equal(received.options.method, 'GET');
    assert.ok(received.options.signal instanceof AbortSignal);

    const unavailable = new BrapiDelayedQuoteGateway({
      token: () => 'synthetic-token',
      clock: () => capturedAt,
      fetchImpl: async () => { throw new Error('raw transport detail'); },
    });
    await assert.rejects(
      unavailable.fetchBatch([{ ticker: 'PETR4', assetType: 'stock' }]),
      { message: 'quote_provider_unavailable' },
    );

    const invalidJson = new BrapiDelayedQuoteGateway({
      token: () => 'synthetic-token',
      clock: () => capturedAt,
      fetchImpl: async () => ({ ok: true, json: async () => { throw new SyntaxError('raw body'); } }),
    });
    await assert.rejects(
      invalidJson.fetchBatch([{ ticker: 'PETR4', assetType: 'stock' }]),
      { message: 'quote_provider_invalid_payload' },
    );
  });
});
