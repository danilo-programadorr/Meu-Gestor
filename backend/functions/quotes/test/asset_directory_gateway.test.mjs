import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createBrapiAssetDirectoryGateway,
  mapDirectoryPayload,
  requireSearchQuery,
} from '../src/brapi_asset_directory_gateway.mjs';

test('normaliza consulta e rejeita texto fora do contrato', () => {
  assert.equal(requireSearchQuery(' petr  '), 'PETR');
  assert.throws(() => requireSearchQuery('p'), { message: 'asset_directory_invalid_query' });
  assert.throws(() => requireSearchQuery('PETR/4'), { message: 'asset_directory_invalid_query' });
});

test('mapeia somente ações e FIIs ativos com identidade pública estrita', () => {
  const result = mapDirectoryPayload({
    results: [
      { symbol: 'PETR4', name: 'Petrobras PN', longName: 'Petróleo Brasileiro S.A.', assetType: 'stock', subType: 'stock', isActive: true },
      { symbol: 'HGLG11', name: 'CSHG Logística', longName: null, assetType: 'fund', subType: 'fii', isActive: true },
      { symbol: 'BOVA11', name: 'ETF', assetType: 'fund', subType: 'etf', isActive: true },
      { symbol: 'VALE3', name: 'Vale', assetType: 'stock', subType: 'stock', isActive: false },
    ],
  });
  assert.deepEqual(result, [
    { ticker: 'PETR4', name: 'Petróleo Brasileiro S.A.', type: 'stock' },
    { ticker: 'HGLG11', name: 'CSHG Logística', type: 'fii' },
  ]);
});

test('envia somente busca fechada, paginação e chave no header e reutiliza cache', async () => {
  const calls = [];
  const gateway = createBrapiAssetDirectoryGateway({
    token: () => 'synthetic-secret',
    clock: () => new Date('2026-10-16T12:00:00.000Z'),
    fetchImpl: async (url, options) => {
      calls.push({ url: url.toString(), options });
      return {
        ok: true,
        json: async () => ({
          results: [{ symbol: 'PETR4', name: 'Petrobras', longName: 'Petróleo Brasileiro S.A.', assetType: 'stock', subType: 'stock', isActive: true }],
        }),
      };
    },
  });

  const first = await gateway.search('petr');
  const second = await gateway.search('PETR');
  assert.deepEqual(second, first);
  assert.equal(calls.length, 1);
  const request = new URL(calls[0].url);
  assert.equal(request.origin + request.pathname, 'https://brapi.dev/api/v2/tickers');
  assert.equal(request.searchParams.get('search'), 'PETR');
  assert.equal(request.searchParams.get('page'), '1');
  assert.equal(request.searchParams.get('limit'), '8');
  assert.equal(request.searchParams.has('token'), false);
  assert.equal(calls[0].options.headers.Authorization, 'Bearer synthetic-secret');
  assert.equal(JSON.stringify(calls[0]).includes('ownerId'), false);
  assert.equal(JSON.stringify(calls[0]).includes('portfolioId'), false);
});

test('não corrige payload inválido nem faz retry automático', async () => {
  let calls = 0;
  const gateway = createBrapiAssetDirectoryGateway({
    token: () => 'synthetic-secret',
    fetchImpl: async () => {
      calls += 1;
      return { ok: true, json: async () => ({ results: 'invalid' }) };
    },
  });
  await assert.rejects(() => gateway.search('PETR'), {
    message: 'asset_directory_invalid_payload',
  });
  assert.equal(calls, 1);
});
