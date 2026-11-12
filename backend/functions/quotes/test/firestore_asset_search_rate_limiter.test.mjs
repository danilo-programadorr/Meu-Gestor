import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createFirestoreAssetSearchRateLimiter } from '../src/firestore_asset_search_rate_limiter.mjs';

class FakeTimestamp {
  constructor(date) { this.date = new Date(date); }
  toDate() { return new Date(this.date); }
  static fromDate(date) { return new FakeTimestamp(date); }
}

function fakeFirestore() {
  const documents = new Map();
  const firestore = {
    collection: (collection) => ({ doc: (id) => ({ path: `${collection}/${id}` }) }),
    runTransaction: async (callback) => callback({
      get: async (reference) => ({
        exists: documents.has(reference.path),
        data: () => documents.get(reference.path),
      }),
      set: (reference, data) => documents.set(reference.path, data),
    }),
  };
  return { firestore, documents };
}

test('conta tentativas por escopo opaco e bloqueia atomicamente no limite', async () => {
  const { firestore, documents } = fakeFirestore();
  const limiter = createFirestoreAssetSearchRateLimiter({
    firestore,
    Timestamp: FakeTimestamp,
    clock: () => new Date('2026-10-26T12:00:00.000Z'),
    limit: 2,
    windowMs: 60_000,
  });

  assert.equal((await limiter.consume({ ownerId: 'synthetic-owner' })).remaining, 1);
  assert.equal((await limiter.consume({ ownerId: 'synthetic-owner' })).remaining, 0);
  await assert.rejects(
    () => limiter.consume({ ownerId: 'synthetic-owner' }),
    { code: 'asset_search_rate_limit_reached' },
  );
  const [[path, stored]] = documents.entries();
  assert.match(path, /^_assetSearchRateLimits\/[a-f0-9]{64}$/u);
  assert.equal(path.includes('synthetic-owner'), false);
  assert.equal(stored.ownerScope.includes('synthetic-owner'), false);
  assert.equal(stored.attemptCount, 2);
});

test('reinicia após a janela e falha fechado para documento inválido', async () => {
  const { firestore, documents } = fakeFirestore();
  let now = new Date('2026-10-26T12:00:00.000Z');
  const limiter = createFirestoreAssetSearchRateLimiter({
    firestore,
    Timestamp: FakeTimestamp,
    clock: () => now,
    limit: 1,
    windowMs: 60_000,
  });
  await limiter.consume({ ownerId: 'synthetic-owner' });
  now = new Date('2026-10-26T12:01:00.000Z');
  assert.equal((await limiter.consume({ ownerId: 'synthetic-owner' })).remaining, 0);

  const [path] = documents.keys();
  documents.set(path, { schemaVersion: 1, attemptCount: 0 });
  await assert.rejects(
    () => limiter.consume({ ownerId: 'synthetic-owner' }),
    { code: 'asset_search_rate_limit_unavailable' },
  );
});
