import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createNewsRefreshHttp } from '../src/news_refresh_http.mjs';
import { NEWS_FUNCTION_OPTIONS } from '../src/function_options.mjs';

function invoke(handler, {
  method = 'POST',
  body = {},
  scheduleTime = '2026-10-11T15:00:00.000Z',
} = {}) {
  const sent = { status: null, body: null };
  const request = {
    method,
    body,
    get(name) {
      return name === 'x-cloudscheduler-scheduletime' ? scheduleTime : undefined;
    },
  };
  const response = {
    status(value) { sent.status = value; return this; },
    json(value) { sent.body = value; return this; },
  };
  return Promise.resolve(handler(request, response)).then(() => sent);
}

function handler(refresh = async () => []) {
  return createNewsRefreshHttp({
    onRequest: (_options, callback) => callback,
    options: { region: 'southamerica-east1' },
    refreshService: { refresh },
    logger: { info() {}, warn() {} },
  });
}

describe('News refresh HTTP boundary', () => {
  test('configuração é privada e limitada a uma instância', () => {
    assert.deepEqual(NEWS_FUNCTION_OPTIONS, {
      region: 'southamerica-east1',
      serviceAccount: NEWS_FUNCTION_OPTIONS.serviceAccount,
      memory: '256MiB',
      timeoutSeconds: 30,
      maxInstances: 1,
      minInstances: 0,
      concurrency: 1,
      invoker: 'private',
      secrets: NEWS_FUNCTION_OPTIONS.secrets,
    });
  });

  test('aceita somente POST vazio com marcador do Scheduler', async () => {
    assert.deepEqual(await invoke(handler(), { method: 'GET' }), {
      status: 405,
      body: { error: 'method_not_allowed' },
    });
    assert.deepEqual(await invoke(handler(), { body: { category: 'market' } }), {
      status: 400,
      body: { error: 'invalid_request' },
    });
    assert.deepEqual(await invoke(handler(), { scheduleTime: null }), {
      status: 400,
      body: { error: 'news_schedule_time_invalid' },
    });
  });

  test('deriva idempotência do instante do Scheduler', async () => {
    let received;
    const result = await invoke(handler(async (input) => {
      received = input;
      return [
        { category: 'market', articles: [{ id: 'one' }] },
        { category: 'economy', articles: [{ id: 'two' }] },
        { category: 'international', articles: [{ id: 'three' }] },
      ];
    }));

    assert.deepEqual(received, { requestId: 'schedule_20261011150000000' });
    assert.deepEqual(result, {
      status: 200,
      body: { categoryCount: 3, articleCount: 3 },
    });
  });

  test('mapeia quota e provedor para status sanitizado', async () => {
    for (const [code, status] of [
      ['news_daily_limit_reached', 429],
      ['news_provider_unavailable', 502],
      ['news_provider_not_configured', 503],
    ]) {
      const error = new Error('provider detail must not escape');
      error.code = code;
      const result = await invoke(handler(async () => { throw error; }));
      assert.deepEqual(result, { status, body: { error: code } });
    }
  });
});
