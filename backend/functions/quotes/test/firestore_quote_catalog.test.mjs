import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { createFirestoreQuoteCatalog } from '../src/firestore_quote_catalog.mjs';

/// Protege o catálogo contra forma aberta, identificação pessoal, tipo
/// incompatível e ampliação silenciosa do limite aprovado.
function timestamp(value = '2026-10-08T12:00:00.000Z') {
  return { toDate: () => new Date(value) };
}

function firestoreWith(documents, expectedLimit = 31) {
  const query = {
    where(field, operator, value) {
      assert.deepEqual([field, operator, value], ['enabled', '==', true]);
      return this;
    },
    limit(value) { assert.equal(value, expectedLimit); return this; },
    async get() { return { size: documents.length, docs: documents }; },
  };
  return { collection(name) { assert.equal(name, '_marketQuoteCatalog'); return query; } };
}

function document(ticker = 'PETR4', overrides = {}) {
  return {
    id: ticker,
    data: () => ({
      ticker,
      assetType: 'stock',
      enabled: true,
      schemaVersion: 1,
      updatedAt: timestamp(),
      ...overrides,
    }),
  };
}

describe('Firestore quote catalog', () => {
  test('normaliza catálogo global sem identificadores de usuário', async () => {
    const targets = await createFirestoreQuoteCatalog({
      firestore: firestoreWith([document('PETR4')]),
    }).readActiveTargets();
    assert.deepEqual(targets, [{ ticker: 'PETR4', assetType: 'stock' }]);
  });

  test('falha fechado para catálogo vazio, ticker não suportado ou schema extra', async () => {
    await assert.rejects(
      createFirestoreQuoteCatalog({ firestore: firestoreWith([]) }).readActiveTargets(),
      { message: 'quote_catalog_empty' },
    );
    await assert.rejects(
      createFirestoreQuoteCatalog({ firestore: firestoreWith([document('INVALID')]) }).readActiveTargets(),
      { message: 'quote_invalid_ticker' },
    );
    await assert.rejects(
      createFirestoreQuoteCatalog({ firestore: firestoreWith([document('PETR4', { ownerId: 'forbidden' })]) }).readActiveTargets(),
      { message: 'quote_catalog_invalid_document' },
    );
  });

  test('aceita vários ativos, mas limita o catálogo ao orçamento mensal conservador', async () => {
    const documents = Array.from({ length: 31 }, (_, index) =>
      document(`TEST${String(index).padStart(2, '0')}`));
    await assert.rejects(
      createFirestoreQuoteCatalog({ firestore: firestoreWith(documents) }).readActiveTargets(),
      { message: 'quote_catalog_limit_exceeded' },
    );
  });

  test('aceita documento automático opaco com contagem de demanda', async () => {
    const automatic = document('VALE3', {
      demandCount: 2,
      lastDemandAt: timestamp(),
      schemaVersion: 2,
    });
    const targets = await createFirestoreQuoteCatalog({
      firestore: firestoreWith([automatic]),
    }).readActiveTargets();
    assert.deepEqual(targets, [{ ticker: 'VALE3', assetType: 'stock' }]);
  });

  test('não permite configurar limite acima do contrato provider-neutral', () => {
    assert.throws(() => createFirestoreQuoteCatalog({
      firestore: firestoreWith([], 1),
      maximumTargets: 51,
    }), { message: 'quote_invalid_catalog_limit' });
  });
});
