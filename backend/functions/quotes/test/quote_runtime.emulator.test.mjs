import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { createQuoteRuntime } from '../src/quote_runtime.mjs';

/// Exercita a composição real contra Firestore Emulator, mantendo somente a
/// fronteira HTTP da BRAPI simulada e sem qualquer credencial ou dado pessoal.
const enabled = typeof process.env.FIRESTORE_EMULATOR_HOST === 'string';
const suite = enabled ? describe : describe.skip;
const projectId = 'demo-meu-gestor-financeiro';
let app;
let firestore;
let Timestamp;
let deleteApp;

suite('Quote runtime with Firestore Emulator', () => {
  before(async () => {
    const appModule = await import('firebase-admin/app');
    const firestoreModule = await import('firebase-admin/firestore');
    deleteApp = appModule.deleteApp;
    Timestamp = firestoreModule.Timestamp;
    app = appModule.initializeApp({ projectId }, `quotes-emulator-${Date.now()}`);
    firestore = firestoreModule.getFirestore(app);
    await firestore.collection('_marketQuoteCatalog').doc('PETR4').set({
      ticker: 'PETR4',
      assetType: 'stock',
      enabled: true,
      schemaVersion: 1,
      updatedAt: Timestamp.fromDate(new Date('2026-10-08T12:00:00.000Z')),
    });
  });

  after(async () => {
    await deleteApp(app);
  });

  test('compõe catálogo, gateway e armazenamento atômico sem dados de usuário', async () => {
    const runtime = createQuoteRuntime({
      firestore,
      Timestamp,
      token: () => 'synthetic-token',
      clock: () => new Date('2026-10-08T15:20:00.000Z'),
      logger: { info() {}, warn() {} },
      fetchImpl: async () => ({
        ok: true,
        json: async () => ({
          results: [{
            symbol: 'PETR4',
            regularMarketPrice: '31.45',
            regularMarketChangePercent: '-1.23',
            regularMarketTime: '2026-10-08T15:05:00.000Z',
            marketState: 'REGULAR',
          }],
        }),
      }),
    });
    const targets = await runtime.catalog.readActiveTargets();
    const snapshots = await runtime.refreshService.refresh({
      requestId: 'emulator_runtime_20261008_152000',
      targets,
    });
    assert.equal(snapshots.length, 1);
    const stored = await firestore.collection('marketQuoteSnapshots').doc('PETR4').get();
    assert.equal(stored.data().priceScaled, 31450000);
    assert.equal(stored.data().source, 'brapi');
    assert.equal(stored.data().ownerId, undefined);
    const request = await firestore.collection('_marketQuoteRefreshRequests')
        .doc('emulator_runtime_20261008_152000__PETR4').get();
    assert.equal(request.data().status, 'completed');
    assert.equal(
      request.data().expiresAt.toDate().toISOString(),
      '2026-11-07T15:20:00.000Z',
    );
    const lease = await firestore.collection('_marketQuoteLeases').doc('PETR4').get();
    assert.equal(lease.exists, false);
  });

  test('falha inválida abre circuito e execução posterior recupera sem sobrescrever por zero', async () => {
    const invalidRuntime = createQuoteRuntime({
      firestore,
      Timestamp,
      token: () => 'synthetic-token',
      clock: () => new Date('2026-10-08T15:30:00.000Z'),
      logger: { info() {}, warn() {} },
      fetchImpl: async () => ({
        ok: true,
        json: async () => ({
          results: [{
            symbol: 'PETR4',
            regularMarketPrice: 0,
            regularMarketChangePercent: 0,
            regularMarketTime: '2026-10-08T15:15:00.000Z',
            marketState: 'REGULAR',
          }],
        }),
      }),
    });
    await assert.rejects(invalidRuntime.refreshService.refresh({
      requestId: 'emulator_invalid_20261008_153000',
      targets: [{ ticker: 'PETR4', assetType: 'stock' }],
    }), { message: 'quote_provider_invalid_price' });
    const preserved = await firestore.collection('marketQuoteSnapshots').doc('PETR4').get();
    assert.equal(preserved.data().priceScaled, 31450000);
    const circuit = await firestore.collection('_marketQuoteCircuitBreakers').doc('PETR4').get();
    assert.equal(circuit.data().lastFailureCode, 'quote_provider_invalid_price');

    await circuit.ref.update({ nextRetryAt: Timestamp.fromDate(new Date('2026-10-08T15:30:00.000Z')) });
    const recoveredRuntime = createQuoteRuntime({
      firestore,
      Timestamp,
      token: () => 'synthetic-token',
      clock: () => new Date('2026-10-08T15:50:00.000Z'),
      logger: { info() {}, warn() {} },
      fetchImpl: async () => ({
        ok: true,
        json: async () => ({
          results: [{
            symbol: 'PETR4',
            regularMarketPrice: '32.10',
            regularMarketChangePercent: '0.50',
            regularMarketTime: '2026-10-08T15:35:00.000Z',
            marketState: 'REGULAR',
          }],
        }),
      }),
    });
    await recoveredRuntime.refreshService.refresh({
      requestId: 'emulator_recovery_20261008_155000',
      targets: [{ ticker: 'PETR4', assetType: 'stock' }],
    });
    const recovered = await firestore.collection('marketQuoteSnapshots').doc('PETR4').get();
    assert.equal(recovered.data().priceScaled, 32100000);
    assert.equal((await circuit.ref.get()).exists, false);
  });

  test('duas execuções concorrentes mantêm uma única chamada por ticker', async () => {
    let release;
    const blocked = new Promise((resolve) => { release = resolve; });
    let calls = 0;
    const runtime = createQuoteRuntime({
      firestore,
      Timestamp,
      token: () => 'synthetic-token',
      clock: () => new Date('2026-10-08T16:20:00.000Z'),
      logger: { info() {}, warn() {} },
      fetchImpl: async () => {
        calls += 1;
        await blocked;
        return {
          ok: true,
          json: async () => ({
            results: [{
              symbol: 'VALE3',
              regularMarketPrice: '62.00',
              regularMarketChangePercent: '1.00',
              regularMarketTime: '2026-10-08T16:05:00.000Z',
              marketState: 'REGULAR',
            }],
          }),
        };
      },
    });
    const input = {
      requestId: 'emulator_concurrent_20261008_162000',
      targets: [{ ticker: 'VALE3', assetType: 'stock' }],
    };
    const first = runtime.refreshService.refresh(input);
    const second = runtime.refreshService.refresh(input);
    await new Promise((resolve) => setTimeout(resolve, 50));
    release();
    await Promise.all([first, second]);
    assert.equal(calls, 1);
    assert.equal((await firestore.collection('marketQuoteSnapshots').doc('VALE3').get()).exists, true);
  });
});
