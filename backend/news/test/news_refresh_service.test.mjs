import assert from 'node:assert/strict';
import test from 'node:test';

import { MarketNewsRefreshService } from '../src/news_refresh_service.mjs';

const now = new Date('2026-10-11T15:00:00.000Z');

function feed(category) {
  return { category, articles: [], fetchedAt: now.toISOString() };
}

test('reserva antes da rede e publica as três categorias juntas', async () => {
  const calls = [];
  const storage = {
    claim: async (input) => { calls.push(['claim', input.requestCount]); return { kind: 'claimed' }; },
    complete: async (input) => calls.push(['complete', input.feeds.map((item) => item.category)]),
    fail: async () => calls.push(['fail']),
    readFeeds: async () => [],
  };
  const service = new MarketNewsRefreshService({
    storage,
    clock: () => now,
    gateway: {
      fetchCategory: async (category) => { calls.push(['fetch', category]); return feed(category); },
    },
  });

  const result = await service.refresh({ requestId: 'schedule_20261011150000000' });

  assert.equal(result.length, 3);
  assert.deepEqual(calls[0], ['claim', 3]);
  assert.deepEqual(calls.slice(1, 4).map((entry) => entry[0]), ['fetch', 'fetch', 'fetch']);
  assert.deepEqual(calls[4], ['complete', ['market', 'economy', 'international']]);
  assert.equal(calls.some((entry) => entry[0] === 'fail'), false);
});

test('falha de uma categoria não publica lote parcial', async () => {
  const calls = [];
  const service = new MarketNewsRefreshService({
    storage: {
      claim: async () => ({ kind: 'claimed' }),
      complete: async () => calls.push('complete'),
      fail: async ({ code }) => calls.push(code),
      readFeeds: async () => [],
    },
    clock: () => now,
    gateway: {
      fetchCategory: async (category) => {
        if (category === 'economy') {
          const error = new Error('private provider detail');
          error.code = 'news_provider_unavailable';
          throw error;
        }
        return feed(category);
      },
    },
  });

  await assert.rejects(
    () => service.refresh({ requestId: 'schedule_20261011150000000' }),
    { message: 'news_provider_unavailable' },
  );
  assert.deepEqual(calls, ['news_provider_unavailable']);
});

test('execução idempotente concluída relê snapshots sem chamar provedor', async () => {
  let providerCalls = 0;
  const stored = [feed('market'), feed('economy'), feed('international')];
  const service = new MarketNewsRefreshService({
    storage: {
      claim: async () => ({ kind: 'completed' }),
      complete: async () => assert.fail('não deve completar novamente'),
      fail: async () => assert.fail('não deve falhar'),
      readFeeds: async () => stored,
    },
    clock: () => now,
    gateway: { fetchCategory: async () => { providerCalls += 1; } },
  });

  const result = await service.refresh({ requestId: 'schedule_20261011150000000' });
  assert.equal(result, stored);
  assert.equal(providerCalls, 0);
});
