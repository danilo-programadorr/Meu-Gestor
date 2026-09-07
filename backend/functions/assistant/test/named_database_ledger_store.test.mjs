import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_NAMED_LEDGER_DATABASE_ID,
  NamedDatabaseAssistantCostLedgerStore,
} from '../src/named_database_ledger_store.mjs';
import { AssistantCostControlLedger } from '../../../assistant/src/cost_control_ledger.mjs';

const createStore = ({ projectId = 'demo-assistant-controls', failAuth = false } = {}) => {
  const requests = [];
  let document = null;
  const client = {
    async request(request) {
      requests.push(request);
      if (request.url.endsWith(':beginTransaction')) return { data: { transaction: 'synthetic-transaction' } };
      if (request.method === 'GET') {
        if (document === null) {
          const error = new Error('not_found');
          error.response = { status: 404 };
          throw error;
        }
        return { data: document };
      }
      if (request.url.endsWith(':commit')) {
        const write = request.data.writes[0].update;
        document = { updateTime: 'synthetic-update-time', fields: write.fields };
        return { data: { writeResults: [{}] } };
      }
      throw new Error('unexpected_request');
    },
  };
  const authFactory = () => failAuth
    ? { getClient: async () => { throw new Error('adc_missing'); }, getProjectId: async () => projectId }
    : { getClient: async () => client, getProjectId: async () => projectId };
  return { store: new NamedDatabaseAssistantCostLedgerStore({ authFactory }), requests };
};

test('ledger usa somente ADC e o banco nomeado, sem banco padrão', async () => {
  const { store, requests } = createStore();
  const result = await store.runTransaction((state) => {
    state.records.request = { tier: 'flash', reservedCostCents: 20 };
    return { accepted: true };
  });
  assert.deepEqual(result, { accepted: true });
  assert.equal(ASSISTANT_NAMED_LEDGER_DATABASE_ID, 'assistant-controls-dev');
  for (const request of requests) {
    assert.match(request.url, /databases\/assistant-controls-dev/u);
    assert.doesNotMatch(request.url, /\(default\)/u);
    assert.doesNotMatch(JSON.stringify(request), /uid|email|token|prompt|response/i);
  }
});

test('reserva e confirmação idempotentes passam pela transação do banco nomeado sem identidade do usuário', async () => {
  const { store, requests } = createStore();
  const ledger = new AssistantCostControlLedger({
    store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  const requestId = '123e4567-e89b-42d3-a456-426614174000';
  const reservation = await ledger.reserve({ maximumCostCents: 20, requestId, tier: 'flash' });
  const repeatedReservation = await ledger.reserve({ maximumCostCents: 20, requestId, tier: 'flash' });
  const confirmation = await ledger.confirm({ confirmedCostCents: 10, durationMs: 42, requestId });
  const repeatedConfirmation = await ledger.confirm({ confirmedCostCents: 10, durationMs: 42, requestId });

  assert.deepEqual(repeatedReservation, reservation);
  assert.deepEqual(repeatedConfirmation, confirmation);
  assert.equal(confirmation.state, 'confirmed');
  assert.equal(requests.filter((request) => request.url.endsWith(':commit')).length, 4);
  assert.doesNotMatch(JSON.stringify(requests), /\b(?:uid|email|authorization|bearer|prompt|response)\b/iu);
});

test('não aceita identidade de usuário e aplica limite diário sem duplicar uma reserva', async () => {
  const { store } = createStore();
  const ledger = new AssistantCostControlLedger({
    store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  const firstRequestId = '123e4567-e89b-42d3-a456-426614174001';
  const secondRequestId = '123e4567-e89b-42d3-a456-426614174002';
  await ledger.reserve({ maximumCostCents: 500, requestId: firstRequestId, tier: 'flash' });
  await assert.rejects(
    ledger.reserve({ maximumCostCents: 1, requestId: secondRequestId, tier: 'flash' }),
    /assistant_named_ledger_unavailable/,
  );
  await assert.rejects(
    store.runTransaction((state, identity) => {
      assert.equal(identity, undefined);
      state.uid = 'cross-user-attempt';
      return {};
    }),
    /assistant_named_ledger_unavailable/,
  );
});

test('falha fechada para ADC indisponível ou banco incompatível', async () => {
  const unavailable = createStore({ failAuth: true });
  await assert.rejects(unavailable.store.runTransaction(() => ({})), /assistant_named_ledger_unavailable/);

  const incorrectProject = createStore({ projectId: '123' });
  await assert.rejects(incorrectProject.store.runTransaction(() => ({})), /assistant_named_ledger_unavailable/);
});

test('falha fechada quando a resposta do banco não preserva o estado estrito do ledger', async () => {
  const { store } = createStore();
  await assert.rejects(
    store.runTransaction((state) => {
      state.unexpected = true;
      return { accepted: true };
    }),
    /assistant_named_ledger_unavailable/,
  );
});
