import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createQuoteRefreshHttp } from '../src/quote_refresh_http.mjs';

function invoke(handler, { method = 'POST', secret = null, body = null } = {}) {
  const sent = { status: null, body: null };
  const request = {
    method,
    body,
    get(name) { return name === 'x-quote-refresh-secret' ? secret : undefined; },
  };
  const response = {
    status(value) { sent.status = value; return this; },
    json(value) { sent.body = value; return this; },
  };
  return Promise.resolve(handler(request, response)).then(() => sent);
}

function handler({ refresh = async () => [] } = {}) {
  return createQuoteRefreshHttp({
    onRequest: (_options, callback) => callback,
    options: { region: 'southamerica-east1' },
    refreshService: { refresh },
    sharedSecret: () => 'synthetic-secret-with-at-least-24-characters',
    logger: { warn() {} },
  });
}

describe('Quote refresh Gen 2 HTTP boundary', () => {
  test('falha fechada sem segredo ou método POST', async () => {
    assert.deepEqual(await invoke(handler(), { method: 'GET' }), {
      status: 405, body: { error: 'method_not_allowed' },
    });
    assert.deepEqual(await invoke(handler(), { secret: 'wrong' }), {
      status: 401, body: { error: 'unauthorized' },
    });
  });

  test('aceita somente contrato interno exato e responde apenas contagem', async () => {
    let received;
    const result = await invoke(handler({
      refresh: async (input) => {
        received = input;
        return [{ ticker: 'PETR4', priceScaled: 31450000 }];
      },
    }), {
      secret: 'synthetic-secret-with-at-least-24-characters',
      body: {
        requestId: 'request_synthetic_20260818',
        targets: [{ ticker: 'PETR4', assetType: 'stock' }],
      },
    });
    assert.equal(result.status, 200);
    assert.deepEqual(result.body, { refreshed: 1 });
    assert.deepEqual(received, {
      requestId: 'request_synthetic_20260818',
      targets: [{ ticker: 'PETR4', assetType: 'stock' }],
    });
  });

  test('não chama processamento quando o segredo de ambiente está ausente', async () => {
    let called = false;
    const unavailable = createQuoteRefreshHttp({
      onRequest: (_options, callback) => callback,
      options: {},
      refreshService: { async refresh() { called = true; return []; } },
      sharedSecret: () => null,
      logger: { warn() {} },
    });
    const result = await invoke(unavailable, {
      secret: 'synthetic-secret-with-at-least-24-characters',
      body: { requestId: 'request_synthetic_20260818', targets: [] },
    });
    assert.deepEqual(result, { status: 503, body: { error: 'quote_refresh_not_configured' } });
    assert.equal(called, false);
  });
});
