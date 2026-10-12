import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createFirestoreNewsStorage } from '../src/firestore_news_storage.mjs';

class FakeTimestamp {
  constructor(value) { this.value = new Date(value); }
  toDate() { return new Date(this.value); }
  static fromDate(value) { return new FakeTimestamp(value); }
}

class FakeSnapshot {
  constructor(value) { this.value = value; }
  get exists() { return this.value !== undefined; }
  data() { return this.value; }
}

function fakeFirestore() {
  const documents = new Map();
  let transactionTail = Promise.resolve();
  const reference = (collection, id) => ({
    path: `${collection}/${id}`,
    async get() { return new FakeSnapshot(documents.get(this.path)); },
  });
  return {
    documents,
    collection(name) { return { doc(id) { return reference(name, id); } }; },
    runTransaction(callback) {
      // Serializa o fake como o Firestore faria ao repetir transações em
      // conflito, permitindo provar lease e quota sob concorrência.
      const result = transactionTail.then(async () => {
      const transaction = {
        async get(ref) { return new FakeSnapshot(documents.get(ref.path)); },
        set(ref, value) { documents.set(ref.path, value); },
        update(ref, value) {
          documents.set(ref.path, { ...documents.get(ref.path), ...value });
        },
        delete(ref) { documents.delete(ref.path); },
      };
      return callback(transaction);
      });
      transactionTail = result.then(() => undefined, () => undefined);
      return result;
    },
  };
}

function feeds(now) {
  return ['market', 'economy', 'international'].map((category, index) => ({
    category,
    provider: 'marketaux',
    fetchedAt: now.toISOString(),
    staleAfter: new Date(now.getTime() + 3 * 60 * 60 * 1000).toISOString(),
    articles: [{
      id: `article_${index}2345678`,
      title: `Notícia ${index}`,
      source: 'example.com',
      articleUrl: `https://example.com/${index}`,
      publishedAt: now.toISOString(),
    }],
    schemaVersion: 1,
  }));
}

describe('Firestore news storage', () => {
  test('reserva três chamadas e publica categorias atomicamente', async () => {
    const firestore = fakeFirestore();
    const storage = createFirestoreNewsStorage({ firestore, Timestamp: FakeTimestamp });
    const now = new Date('2026-10-11T15:00:00.000Z');

    assert.deepEqual(await storage.claim({
      requestId: 'schedule_20261011150000000',
      now,
      requestCount: 3,
    }), { kind: 'claimed' });
    assert.equal(
      firestore.documents.get('_marketNewsDailyUsage/2026-10-11').requestCount,
      3,
    );

    await storage.complete({
      requestId: 'schedule_20261011150000000',
      feeds: feeds(now),
      now,
    });
    assert.equal(firestore.documents.has('_marketNewsLeases/current'), false);
    assert.equal(firestore.documents.get('marketNewsFeeds/market').provider, 'marketaux');
    assert.equal(firestore.documents.get('marketNewsFeeds/economy').articles.length, 1);
    assert.equal(
      firestore.documents.get('_marketNewsRefreshRequests/schedule_20261011150000000').status,
      'completed',
    );
  });

  test('limite interno impede a chamada 91 antes da rede', async () => {
    const firestore = fakeFirestore();
    const storage = createFirestoreNewsStorage({ firestore, Timestamp: FakeTimestamp });
    const base = new Date('2026-10-11T00:00:00.000Z');
    for (let index = 0; index < 30; index += 1) {
      const now = new Date(base.getTime() + index * 2 * 60 * 1000);
      await storage.claim({
        requestId: `schedule_20261011_${String(index).padStart(16, '0')}`,
        now,
        requestCount: 3,
      });
      firestore.documents.delete('_marketNewsLeases/current');
    }
    assert.equal(
      firestore.documents.get('_marketNewsDailyUsage/2026-10-11').requestCount,
      90,
    );
    await assert.rejects(
      storage.claim({
        requestId: 'schedule_20261011_limit0000000000000000',
        now: new Date('2026-10-11T23:00:00.000Z'),
        requestCount: 3,
      }),
      { message: 'news_daily_limit_reached' },
    );
  });

  test('falha e retry idempotente preservam a reserva já contabilizada', async () => {
    const firestore = fakeFirestore();
    const storage = createFirestoreNewsStorage({ firestore, Timestamp: FakeTimestamp });
    const now = new Date('2026-10-11T15:00:00.000Z');
    const requestId = 'schedule_20261011150000000';

    assert.deepEqual(await storage.claim({ requestId, now, requestCount: 3 }), {
      kind: 'claimed',
    });
    await storage.fail({
      requestId,
      now,
      code: 'news_provider_unavailable',
    });

    assert.deepEqual(await storage.claim({
      requestId,
      now: new Date('2026-10-11T15:01:00.000Z'),
      requestCount: 3,
    }), { kind: 'failed' });
    assert.equal(
      firestore.documents.get('_marketNewsDailyUsage/2026-10-11').requestCount,
      3,
    );
  });

  test('execução manual única conta e concorrência não duplica reserva', async () => {
    const firestore = fakeFirestore();
    const storage = createFirestoreNewsStorage({ firestore, Timestamp: FakeTimestamp });
    const now = new Date('2026-10-11T18:00:00.000Z');

    const [first, second] = await Promise.all([
      storage.claim({
        requestId: 'manual_20261011180000000001',
        now,
        requestCount: 3,
      }),
      storage.claim({
        requestId: 'manual_20261011180000000002',
        now,
        requestCount: 3,
      }),
    ]);

    assert.deepEqual(first, { kind: 'claimed' });
    assert.deepEqual(second, { kind: 'leased' });
    assert.equal(
      firestore.documents.get('_marketNewsDailyUsage/2026-10-11').requestCount,
      3,
    );
  });
});
