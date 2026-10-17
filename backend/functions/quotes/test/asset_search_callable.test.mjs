import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createAssetSearchCallable } from '../src/asset_search_callable.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function harness(directory) {
  const calls = [];
  const logs = [];
  const handler = createAssetSearchCallable({
    onCall: (options, callback) => { calls.push(options); return callback; },
    HttpsError: FakeHttpsError,
    options: Object.freeze({ enforceAppCheck: true }),
    directory,
    logger: {
      info: (event, detail) => logs.push({ event, detail }),
      warn: (event, detail) => logs.push({ event, detail }),
    },
  });
  return { handler, calls, logs };
}

const request = (data = { query: 'PETR' }) => ({
  auth: { uid: 'synthetic-owner', token: { email_verified: true } },
  app: { appId: 'synthetic-app' },
  data,
});

test('exige Auth, e-mail verificado, App Check e contrato exato', async () => {
  const { handler, calls } = harness({ search: async () => [] });
  assert.equal(calls[0].enforceAppCheck, true);
  await assert.rejects(() => handler({ ...request(), auth: null }), { code: 'unauthenticated' });
  await assert.rejects(() => handler({ ...request(), auth: { uid: 'x', token: {} } }), { code: 'permission-denied' });
  await assert.rejects(() => handler({ ...request(), app: null }), { code: 'failed-precondition' });
  await assert.rejects(() => handler(request({ query: 'PETR', ownerId: 'forbidden' })), { code: 'invalid-argument' });
});

test('retorna envelope mínimo e logs sem consulta ou identidade', async () => {
  const { handler, logs } = harness({
    search: async () => [{ ticker: 'PETR4', name: 'Petróleo Brasileiro S.A.', type: 'stock' }],
  });
  const response = await handler(request());
  assert.deepEqual(response, {
    schemaVersion: 1,
    results: [{ ticker: 'PETR4', name: 'Petróleo Brasileiro S.A.', type: 'stock' }],
  });
  assert.deepEqual(logs, [{
    event: 'asset_directory_search',
    detail: { outcome: 'passed', resultCount: 1 },
  }]);
  assert.equal(JSON.stringify(logs).includes('PETR'), false);
  assert.equal(JSON.stringify(logs).includes('synthetic-owner'), false);
});

test('reduz falha do provedor a classe sanitizada', async () => {
  const error = new Error('raw provider detail');
  error.code = 'asset_directory_timeout';
  const { handler, logs } = harness({ search: async () => { throw error; } });
  await assert.rejects(() => handler(request()), { code: 'deadline-exceeded' });
  assert.deepEqual(logs[0], {
    event: 'asset_directory_search',
    detail: { outcome: 'failed', reason: 'timeout' },
  });
  assert.equal(JSON.stringify(logs).includes('raw provider detail'), false);
});
