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
    assert.equal(quote.staleAfter, '2026-08-18T15:45:00.000Z');
  });

  test('preserva o último fechamento depois do pregão até a próxima janela de atualização', () => {
    const [quote] = mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-18T20:55:00.000Z' }),
      targets,
      capturedAt: new Date('2026-08-18T21:30:00.000Z'),
    });
    assert.equal(quote.status, 'marketClosed');
    assert.equal(quote.staleAfter, '2026-08-19T13:45:00.000Z');
  });

  test('mantém o fechamento de sexta-feira durante o fim de semana', () => {
    const [quote] = mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-21T20:55:00.000Z' }),
      targets,
      capturedAt: new Date('2026-08-21T21:30:00.000Z'),
    });
    assert.equal(quote.status, 'marketClosed');
    assert.equal(quote.staleAfter, '2026-08-24T13:45:00.000Z');
  });

  test('vence o fechamento anterior após a primeira atualização do próprio dia', () => {
    const [quote] = mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-17T20:55:00.000Z' }),
      targets,
      capturedAt: new Date('2026-08-18T11:30:00.000Z'),
    });
    assert.equal(quote.status, 'marketClosed');
    assert.equal(quote.staleAfter, '2026-08-18T13:45:00.000Z');
  });

  test('distingue fechamento anterior durante a sessão e recusa observação antiga demais', () => {
    const [quote] = mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-17T20:55:00.000Z' }),
      targets,
      capturedAt: new Date('2026-08-18T13:05:00.000Z'),
    });
    assert.equal(quote.status, 'marketClosed');
    assert.equal(quote.staleAfter, '2026-08-18T13:50:00.000Z');

    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-13T20:55:00.000Z' }),
      targets,
      capturedAt: new Date('2026-08-18T21:30:00.000Z'),
    }), { message: 'quote_provider_stale_quote' });
  });

  test('não exige estado de mercado ausente no schema oficial e recusa dados inválidos', () => {
    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketPrice: 0 }), targets, capturedAt,
    }), { message: 'quote_provider_invalid_price' });
    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-19T00:00:00.000Z' }), targets, capturedAt,
    }), { message: 'quote_provider_invalid_observed_at' });
    assert.throws(() => mapBrapiPayload({
      payload: payload({ symbol: 'UNKN3' }), targets, capturedAt,
    }), { message: 'quote_provider_unexpected_result' });
    assert.throws(() => mapBrapiPayload({
      payload: payload({ regularMarketTime: '2026-08-18T13:59:59.000Z' }), targets, capturedAt,
    }), { message: 'quote_provider_stale_quote' });
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
    assert.equal(received.url.searchParams.has('token'), false);
    assert.equal(received.url.searchParams.get('range'), '1d');
    assert.equal(received.options.method, 'GET');
    assert.equal(received.options.headers.Authorization, 'Bearer synthetic-token');
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
