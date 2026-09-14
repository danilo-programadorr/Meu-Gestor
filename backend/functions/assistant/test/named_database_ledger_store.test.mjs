import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_NAMED_LEDGER_DATABASE_ID,
  NamedDatabaseAssistantCostLedgerStore,
} from '../src/named_database_ledger_store.mjs';
import {
  AssistantCostControlLedger,
  createAssistantOwnerScope,
} from '../../../assistant/src/cost_control_ledger.mjs';

const ownerScope = createAssistantOwnerScope('synthetic-owner');
const rejectsReason = (promise, diagnosticReason) => assert.rejects(
  promise,
  (error) => error?.message === 'assistant_named_ledger_unavailable'
    && error?.diagnosticReason === diagnosticReason,
);
const state = () => ({
  daily: {}, monthly: {}, periods: {}, records: {},
  usage: {
    [ownerScope]: {
      windowDay: '2026-09-07', costUnitsInWindow: 0, proCallsInWindow: 0,
    },
  },
});
const createStore = ({
  projectId = 'demo-assistant-controls',
  failAuth = false,
  documentPresent = true,
  ledgerState = state(),
  requestFailure = null,
  runtimeDiagnostics = undefined,
} = {}) => {
  const requests = [];
  let document = documentPresent
    ? { updateTime: 'synthetic-update-time', fields: { state: { stringValue: JSON.stringify(ledgerState) } } }
    : null;
  const client = {
    async request(request) {
      requests.push(request);
      const failure = typeof requestFailure === 'function'
        ? requestFailure(request)
        : requestFailure;
      if (failure !== null) throw failure;
      if (request.url.endsWith('/documents:beginTransaction')) {
        return { status: 200, data: { transaction: 'synthetic-transaction' } };
      }
      if (request.method === 'GET') {
        if (document === null) {
          const error = new Error('not_found');
          error.response = { status: 404 };
          throw error;
        }
        return { status: 200, data: document };
      }
      if (request.url.endsWith('/documents:commit')) {
        const write = request.data.writes[0].update;
        document = { updateTime: 'synthetic-update-time', fields: write.fields };
        return { status: 200, data: { writeResults: [{}] } };
      }
      throw new Error('unexpected_request');
    },
  };
  const authFactory = () => failAuth
    ? { getClient: async () => { throw new Error('adc_missing'); }, getProjectId: async () => projectId }
    : { getClient: async () => client, getProjectId: async () => projectId };
  return {
    store: new NamedDatabaseAssistantCostLedgerStore({ authFactory, runtimeDiagnostics }),
    requests,
  };
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

test('usa rotas REST oficiais e propaga a mesma transação entre leitura e commit', async () => {
  const { store, requests } = createStore();
  await store.runTransaction(() => ({ accepted: true }));

  const root = 'https://firestore.googleapis.com/v1/projects/demo-assistant-controls/databases/assistant-controls-dev';
  assert.equal(requests.length, 3);
  assert.deepEqual(requests[0], {
    method: 'POST', url: `${root}/documents:beginTransaction`, data: {},
  });
  assert.deepEqual(requests[1], {
    method: 'GET',
    url: `${root}/documents/assistantRuntime/ledger?transaction=synthetic-transaction`,
  });
  assert.equal(requests[2].method, 'POST');
  assert.equal(requests[2].url, `${root}/documents:commit`);
  assert.equal(requests[2].data.transaction, 'synthetic-transaction');
  assert.equal(requests[2].data.writes.length, 1);
  assert.equal(requests[2].data.writes[0].update.name, `${root}/documents/assistantRuntime/ledger`);
  assert.ok(requests.every((request) => !/assistant-controls-dev:(?:beginTransaction|commit)$/u.test(request.url)));
});

test('diagnostica ADC e transporte HTTP sem alterar resultado ou expor requisição', async () => {
  const events = [];
  const runtimeDiagnostics = { report: (event) => events.push(event) };
  const { store } = createStore({ runtimeDiagnostics });

  assert.deepEqual(await store.runTransaction(() => ({ accepted: true })), { accepted: true });
  assert.deepEqual(events, [
    { stage: 'usage_adc_credentials', outcome: 'started' },
    { stage: 'usage_adc_credentials', outcome: 'passed' },
    { stage: 'usage_firestore_begin_transaction', outcome: 'started' },
    { stage: 'usage_firestore_begin_transaction', outcome: 'passed', httpStatus: 200 },
    { stage: 'usage_firestore_read', outcome: 'started' },
    { stage: 'usage_firestore_read', outcome: 'passed', httpStatus: 200 },
    { stage: 'usage_firestore_commit', outcome: 'started' },
    { stage: 'usage_firestore_commit', outcome: 'passed', httpStatus: 200 },
  ]);
  assert.ok(events.every((event) => Object.keys(event).every(
    (key) => ['stage', 'outcome', 'reason', 'httpStatus'].includes(key),
  )));
  assert.doesNotMatch(JSON.stringify(events), /synthetic|bearer|@/iu);
});

test('falha interna do diagnóstico não altera a transação', async () => {
  const { store } = createStore({
    runtimeDiagnostics: { report: () => { throw new Error('diagnostics_unavailable'); } },
  });

  assert.deepEqual(await store.runTransaction(() => ({ accepted: true })), { accepted: true });
});

test('reserva e confirmação idempotentes passam pela transação do banco nomeado sem identidade do usuário', async () => {
  const { store, requests } = createStore();
  const ledger = new AssistantCostControlLedger({
    store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  const requestId = '123e4567-e89b-42d3-a456-426614174000';
  const reservation = await ledger.reserve({ maximumCostCents: 20, ownerScope, requestId, tier: 'flash', usageCostUnits: 1 });
  const repeatedReservation = await ledger.reserve({ maximumCostCents: 20, ownerScope, requestId, tier: 'flash', usageCostUnits: 1 });
  const confirmation = await ledger.confirm({ confirmedCostCents: 10, durationMs: 42, requestId });
  const repeatedConfirmation = await ledger.confirm({ confirmedCostCents: 10, durationMs: 42, requestId });

  assert.deepEqual(repeatedReservation, reservation);
  assert.deepEqual(repeatedConfirmation, confirmation);
  assert.equal(confirmation.state, 'confirmed');
  assert.equal(requests.filter((request) => request.url.endsWith('/documents:commit')).length, 4);
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
  await ledger.reserve({ maximumCostCents: 500, ownerScope, requestId: firstRequestId, tier: 'flash', usageCostUnits: 1 });
  await rejectsReason(
    ledger.reserve({ maximumCostCents: 1, ownerScope, requestId: secondRequestId, tier: 'flash', usageCostUnits: 1 }),
    'limit_exceeded',
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
  const events = [];
  const unavailable = createStore({
    failAuth: true,
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });
  await rejectsReason(
    unavailable.store.runTransaction(() => ({})),
    'adc_authentication_unavailable',
  );
  assert.deepEqual(events, [
    { stage: 'usage_adc_credentials', outcome: 'started' },
    {
      stage: 'usage_adc_credentials',
      outcome: 'failed',
      reason: 'adc_authentication_unavailable',
    },
  ]);

  const incorrectProject = createStore({ projectId: '123' });
  await assert.rejects(incorrectProject.store.runTransaction(() => ({})), /assistant_named_ledger_unavailable/);
});

test('falha fechada quando o documento de controle ou o registro do proprietário não existe', async () => {
  const missingDocumentEvents = [];
  const missingDocument = createStore({
    documentPresent: false,
    runtimeDiagnostics: { report: (event) => missingDocumentEvents.push(event) },
  });
  const missingDocumentLedger = new AssistantCostControlLedger({
    store: missingDocument.store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  await rejectsReason(
    missingDocumentLedger.readUsage({ ownerScope }),
    'document_missing',
  );
  assert.deepEqual(missingDocumentEvents.slice(-2), [
    { stage: 'usage_firestore_read', outcome: 'started' },
    {
      stage: 'usage_firestore_read',
      outcome: 'failed',
      reason: 'document_missing',
      httpStatus: 404,
    },
  ]);

  const missingOwner = createStore();
  const missingOwnerLedger = new AssistantCostControlLedger({
    store: missingOwner.store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  await rejectsReason(
    missingOwnerLedger.readUsage({ ownerScope: createAssistantOwnerScope('other-synthetic-owner') }),
    'document_missing',
  );

  const invalidSchema = createStore({ ledgerState: { usage: {} } });
  const invalidSchemaLedger = new AssistantCostControlLedger({
    store: invalidSchema.store,
    clock: () => new Date('2026-09-07T12:00:00.000Z'),
  });
  await rejectsReason(
    invalidSchemaLedger.readUsage({ ownerScope }),
    'schema_invalid',
  );
});

test('classifica autorização e timeout somente pelos sinais técnicos da origem', async () => {
  const denied = new Error('opaque');
  denied.response = { status: 403 };
  const deniedEvents = [];
  await rejectsReason(
    createStore({
      requestFailure: denied,
      runtimeDiagnostics: { report: (event) => deniedEvents.push(event) },
    }).store.runTransaction(() => ({})),
    'authorization_denied',
  );
  assert.deepEqual(deniedEvents.slice(-2), [
    { stage: 'usage_firestore_begin_transaction', outcome: 'started' },
    {
      stage: 'usage_firestore_begin_transaction',
      outcome: 'failed',
      reason: 'authorization_denied',
      httpStatus: 403,
    },
  ]);

  const timeout = new Error('opaque');
  timeout.code = 'ETIMEDOUT';
  await rejectsReason(
    createStore({ requestFailure: timeout }).store.runTransaction(() => ({})),
    'timeout',
  );
});

test('falha de commit preserva status sanitizado e não retorna sucesso parcial', async () => {
  const events = [];
  const timeout = new Error('opaque');
  timeout.response = { status: 504 };
  const { store } = createStore({
    requestFailure: (request) => request.url.endsWith('/documents:commit') ? timeout : null,
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  await rejectsReason(store.runTransaction(() => ({ accepted: true })), 'timeout');
  assert.deepEqual(events.slice(-2), [
    { stage: 'usage_firestore_commit', outcome: 'started' },
    {
      stage: 'usage_firestore_commit',
      outcome: 'failed',
      reason: 'timeout',
      httpStatus: 504,
    },
  ]);
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
