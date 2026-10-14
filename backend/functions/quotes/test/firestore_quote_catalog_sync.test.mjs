import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  createFirestoreQuoteCatalogSync,
  QUOTE_DEMAND_COLLECTION,
} from '../src/firestore_quote_catalog_sync.mjs';
import { QUOTE_CATALOG_COLLECTION } from '../src/firestore_quote_catalog.mjs';

const Timestamp = { fromDate: (value) => ({ toDate: () => new Date(value) }) };

/// Firestore sintético limitado às transações e consultas usadas pelo sync.
class FakeFirestore {
  constructor() { this.collections = new Map(); }

  collection(name) {
    const store = this.collections.get(name) ?? new Map();
    this.collections.set(name, store);
    return {
      doc: (id) => ({ kind: 'doc', name, id, store }),
      where: (field, operator, value) => {
        const filters = [[field, operator, value]];
        return {
          kind: 'query', name, store, filters,
          where(nextField, nextOperator, nextValue) {
            filters.push([nextField, nextOperator, nextValue]);
            return this;
          },
        };
      },
    };
  }

  async runTransaction(callback) {
    return callback({
      get: async (reference) => {
        if (reference.kind === 'query') {
          const docs = [...reference.store.entries()]
              .filter(([, data]) => reference.filters.every(([field, operator, value]) =>
                operator === '==' && data[field] === value))
              .map(([id, data]) => ({ id, data: () => data }));
          return { docs, size: docs.length };
        }
        const data = reference.store.get(reference.id);
        return { exists: data !== undefined, id: reference.id, data: () => data };
      },
      set: (reference, data) => reference.store.set(reference.id, data),
    });
  }

  data(collection, id) { return this.collections.get(collection)?.get(id); }
}

function snapshot({ ownerId, ticker = 'PETR4', assetType = 'stock', revision = 1, archived = false, at }) {
  return {
    exists: true,
    data: () => ({
      ownerId,
      ticker,
      assetType,
      revision,
      schemaVersion: 2,
      isArchived: archived,
      updatedAt: Timestamp.fromDate(new Date(at)),
    }),
  };
}

function event({ userId, assetId, before = { exists: false }, after = { exists: false }, time }) {
  return { params: { userId, assetId }, data: { before, after }, time };
}

describe('Firestore quote catalog sync', () => {
  test('deduplica o mesmo ticker sem persistir proprietário ou carteira', async () => {
    const firestore = new FakeFirestore();
    const sync = createFirestoreQuoteCatalogSync({ firestore, Timestamp, logger: { info() {} } });
    await sync(event({
      userId: 'owner-a', assetId: 'wallet-a__PETR4',
      after: snapshot({ ownerId: 'owner-a', at: '2026-10-13T12:00:00Z' }),
      time: '2026-10-13T12:00:01Z',
    }));
    await sync(event({
      userId: 'owner-b', assetId: 'wallet-b__PETR4',
      after: snapshot({ ownerId: 'owner-b', at: '2026-10-13T12:01:00Z' }),
      time: '2026-10-13T12:01:01Z',
    }));
    const catalog = firestore.data(QUOTE_CATALOG_COLLECTION, 'PETR4');
    assert.equal(catalog.enabled, true);
    assert.equal(catalog.demandCount, 2);
    const serialized = JSON.stringify([
      ...firestore.collections.get(QUOTE_DEMAND_COLLECTION).values(), catalog,
    ]);
    assert.doesNotMatch(serialized, /owner-|wallet-/u);
  });

  test('arquivamento reduz demanda e último ativo retira ticker do catálogo', async () => {
    const firestore = new FakeFirestore();
    const sync = createFirestoreQuoteCatalogSync({ firestore, Timestamp, logger: { info() {} } });
    const active = snapshot({ ownerId: 'owner-a', at: '2026-10-13T12:00:00Z' });
    await sync(event({
      userId: 'owner-a', assetId: 'wallet__PETR4', after: active,
      time: '2026-10-13T12:00:01Z',
    }));
    await sync(event({
      userId: 'owner-a', assetId: 'wallet__PETR4', before: active,
      after: snapshot({
        ownerId: 'owner-a', revision: 2, archived: true, at: '2026-10-13T12:05:00Z',
      }),
      time: '2026-10-13T12:05:01Z',
    }));
    const catalog = firestore.data(QUOTE_CATALOG_COLLECTION, 'PETR4');
    assert.equal(catalog.enabled, false);
    assert.equal(catalog.demandCount, 0);
  });

  test('ignora evento antigo e desabilita conflito de classe sem escolher silenciosamente', async () => {
    const firestore = new FakeFirestore();
    const sync = createFirestoreQuoteCatalogSync({ firestore, Timestamp, logger: { info() {} } });
    await sync(event({
      userId: 'owner-a', assetId: 'first__PETR4',
      after: snapshot({ ownerId: 'owner-a', revision: 2, at: '2026-10-13T12:05:00Z' }),
      time: '2026-10-13T12:05:01Z',
    }));
    await sync(event({
      userId: 'owner-a', assetId: 'first__PETR4',
      after: snapshot({ ownerId: 'owner-a', revision: 1, at: '2026-10-13T12:00:00Z' }),
      time: '2026-10-13T12:00:01Z',
    }));
    assert.equal(firestore.data(QUOTE_CATALOG_COLLECTION, 'PETR4').demandCount, 1);
    await sync(event({
      userId: 'owner-b', assetId: 'second__PETR4',
      after: snapshot({
        ownerId: 'owner-b', assetType: 'fii', at: '2026-10-13T12:10:00Z',
      }),
      time: '2026-10-13T12:10:01Z',
    }));
    assert.equal(firestore.data(QUOTE_CATALOG_COLLECTION, 'PETR4').enabled, false);
  });
});
