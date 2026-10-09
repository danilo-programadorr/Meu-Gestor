import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createQuoteRefreshHttp } from '../src/quote_refresh_http.mjs';
import { QUOTE_FUNCTION_OPTIONS } from '../src/function_options.mjs';

function invoke(handler, {
  method = 'POST',
  body = {},
  scheduleTime = '2026-10-08T15:00:00.000Z',
} = {}) {
  const sent = { status: null, body: null };
  const request = {
    method,
    body,
    get(name) { return name === 'x-cloudscheduler-scheduletime' ? scheduleTime : undefined; },
  };
  const response = {
    status(value) { sent.status = value; return this; },
    json(value) { sent.body = value; return this; },
  };
  return Promise.resolve(handler(request, response)).then(() => sent);
}

function handler({ refresh = async () => [], targets = [{ ticker: 'PETR4', assetType: 'stock' }] } = {}) {
  return createQuoteRefreshHttp({
    onRequest: (_options, callback) => callback,
    options: { region: 'southamerica-east1' },
    catalog: { async readActiveTargets() { return targets; } },
    refreshService: { refresh },
    logger: { info() {}, warn() {} },
  });
}

describe('Quote refresh Gen 2 HTTP boundary', () => {
  test('bootstrap é privado, mínimo e limitado a uma instância', () => {
    assert.deepEqual(QUOTE_FUNCTION_OPTIONS, {
      region: 'southamerica-east1',
      serviceAccount: QUOTE_FUNCTION_OPTIONS.serviceAccount,
      memory: '256MiB',
      timeoutSeconds: 30,
      maxInstances: 1,
      minInstances: 0,
      concurrency: 1,
      invoker: 'private',
      secrets: QUOTE_FUNCTION_OPTIONS.secrets,
    });
  });

  test('falha fechada sem marcador do Scheduler ou método POST', async () => {
    assert.deepEqual(await invoke(handler(), { method: 'GET' }), {
      status: 405, body: { error: 'method_not_allowed' },
    });
    assert.deepEqual(await invoke(handler(), { scheduleTime: null }), {
      status: 400, body: { error: 'quote_invalid_schedule_time' },
    });
  });

  test('obtém alvos somente do catálogo e deriva request id do Scheduler', async () => {
    let received;
    const result = await invoke(handler({
      refresh: async (input) => {
        received = input;
        return [{ ticker: 'PETR4', priceScaled: 31450000 }];
      },
    }), {
      body: {},
    });
    assert.deepEqual(result, { status: 200, body: { refreshed: 1, targetCount: 1 } });
    assert.deepEqual(received, {
      requestId: 'schedule_20261008150000000',
      targets: [{ ticker: 'PETR4', assetType: 'stock' }],
    });
  });

  test('rejeita alvos arbitrários no payload antes de ler catálogo', async () => {
    let called = false;
    const result = await invoke(handler({
      refresh: async () => { called = true; return []; },
    }), {
      body: { targets: [{ ticker: 'PETR4', assetType: 'stock' }] },
    });
    assert.deepEqual(result, { status: 400, body: { error: 'invalid_request' } });
    assert.equal(called, false);
  });

  test('preserva somente código sanitizado e status de falha do provedor', async () => {
    const error = new Error('conteúdo externo não deve aparecer');
    error.code = 'quote_provider_unavailable';
    const result = await invoke(handler({ refresh: async () => { throw error; } }));
    assert.deepEqual(result, { status: 502, body: { error: 'quote_provider_unavailable' } });
  });
});
