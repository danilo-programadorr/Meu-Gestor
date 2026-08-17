import assert from 'node:assert/strict';
import test from 'node:test';
import { FirestoreSubscriptionTransactionalStorage, SubscriptionError } from '../src/index.mjs';

test('Firestore transactional adapter delegates atomic read and write without SDK', async () => {
  let state = { entitlements: new Map([['synthetic-owner', { revision: 1 }]]) };
  const writes = [];
  const storage = new FirestoreSubscriptionTransactionalStorage({
    runTransaction: async (operation) => operation(Object.freeze({ kind: 'synthetic-transaction' })),
    readState: async () => structuredClone(state),
    writeState: async (_transaction, next) => { writes.push(next); state = structuredClone(next); },
    readSnapshot: async () => structuredClone(state),
    readEntitlement: async (ownerId) => state.entitlements.get(ownerId) ?? null,
  });
  const result = await storage.transaction((draft) => {
    draft.entitlements.set('synthetic-owner', { revision: 2 });
    return { revision: 2 };
  });
  assert.deepEqual(result, { revision: 2 });
  assert.equal(writes.length, 1);
  assert.deepEqual(await storage.entitlement('synthetic-owner'), { revision: 2 });
});

test('Firestore transactional adapter fails closed without all injected operations', () => {
  assert.throws(
    () => new FirestoreSubscriptionTransactionalStorage({}),
    (error) => error instanceof SubscriptionError && error.code === 'invalid_firestore_storage_adapter',
  );
});
