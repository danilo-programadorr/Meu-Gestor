import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MarketauxNewsGateway,
  mapMarketauxPayload,
} from '../src/marketaux_gateway.mjs';

const now = new Date('2026-10-11T15:00:00.000Z');

function article(overrides = {}) {
  return {
    uuid: 'article_12345678',
    title: 'Mercado acompanha a decisão de juros',
    source: 'example.com',
    url: 'https://example.com/mercado/juros',
    published_at: '2026-10-11T14:30:00.000Z',
    ...overrides,
  };
}

test('serializa consulta fixa com idioma e três matérias', async () => {
  let receivedUrl;
  const gateway = new MarketauxNewsGateway({
    apiToken: () => 'private-test-token',
    clock: () => now,
    fetchImpl: async (url, options) => {
      receivedUrl = url;
      assert.equal(options.method, 'GET');
      assert.equal(options.headers.Accept, 'application/json');
      return { ok: true, status: 200, json: async () => ({ data: [article()] }) };
    },
  });

  const feed = await gateway.fetchCategory('market');

  assert.equal(receivedUrl.origin, 'https://api.marketaux.com');
  assert.equal(receivedUrl.pathname, '/v1/news/all');
  assert.equal(receivedUrl.searchParams.get('language'), 'pt');
  assert.equal(receivedUrl.searchParams.get('search'), 'mercado');
  assert.equal(receivedUrl.searchParams.get('limit'), '3');
  assert.equal(receivedUrl.searchParams.get('page'), '1');
  assert.equal(receivedUrl.searchParams.get('api_token'), 'private-test-token');
  assert.equal(feed.category, 'market');
  assert.equal(feed.articles.length, 1);
});

test('mapeia somente campos públicos permitidos e normaliza texto', () => {
  const feed = mapMarketauxPayload({
    category: 'economy',
    fetchedAt: now,
    payload: {
      data: [article({ title: '  Inflação   desacelera no mês  ' })],
      ignored: 'provider-metadata',
    },
  });

  assert.deepEqual(Object.keys(feed).sort(), [
    'articles',
    'category',
    'fetchedAt',
    'provider',
    'schemaVersion',
    'staleAfter',
  ]);
  assert.deepEqual(Object.keys(feed.articles[0]).sort(), [
    'articleUrl',
    'id',
    'publishedAt',
    'source',
    'title',
  ]);
  assert.equal(feed.articles[0].title, 'Inflação desacelera no mês');
});

test('rejeita payload, URL e quantidade incompatíveis', () => {
  assert.throws(
    () => mapMarketauxPayload({ category: 'market', payload: {}, fetchedAt: now }),
    { message: 'news_provider_payload_invalid' },
  );
  assert.throws(
    () => mapMarketauxPayload({
      category: 'market',
      fetchedAt: now,
      payload: { data: [article({ url: 'http://example.com/noticia' })] },
    }),
    { message: 'news_article_url_invalid' },
  );
  assert.throws(
    () => mapMarketauxPayload({
      category: 'market',
      fetchedAt: now,
      payload: { data: [article(), article({ uuid: 'article_22345678' }), article({ uuid: 'article_32345678' }), article({ uuid: 'article_42345678' })] },
    }),
    { message: 'news_provider_result_limit_exceeded' },
  );
});

test('distingue quota, indisponibilidade e resposta inválida', async () => {
  for (const [response, code] of [
    [{ ok: false, status: 429 }, 'news_provider_quota_exceeded'],
    [{ ok: false, status: 503 }, 'news_provider_unavailable'],
    [{ ok: true, status: 200, json: async () => { throw new Error('invalid'); } }, 'news_provider_payload_invalid'],
  ]) {
    const gateway = new MarketauxNewsGateway({
      apiToken: () => 'private-test-token',
      clock: () => now,
      fetchImpl: async () => response,
    });
    await assert.rejects(() => gateway.fetchCategory('international'), { message: code });
  }
});
