/** Valida o protocolo REST real do ledger contra o Firestore Emulator. */
import assert from 'node:assert/strict';
import test from 'node:test';

import { createAssistantOwnerScope } from '../../../assistant/src/cost_control_ledger.mjs';
import { NamedDatabaseAssistantCostLedgerStore } from '../src/named_database_ledger_store.mjs';

const emulator = process.env.FIRESTORE_EMULATOR_HOST;
const projectId = 'demo-assistant-controls';
const databaseId = 'assistant-controls-dev';
const api = emulator && `http://${emulator}/v1/projects/${projectId}/databases/${databaseId}`;
const authorization = 'Bearer owner';

test('Emulator aceita begin, read e commit com resource name canônico', {
  skip: !emulator,
}, async () => {
  const ownerScope = createAssistantOwnerScope('synthetic-emulator-owner');
  const state = {
    daily: {}, monthly: {}, periods: {}, records: {},
    usage: {
      [ownerScope]: {
        windowDay: '2026-09-14', costUnitsInWindow: 0, proCallsInWindow: 0,
      },
    },
  };
  const seed = await fetch(`${api}/documents/assistantRuntime/ledger`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: authorization },
    body: JSON.stringify({ fields: {
      schemaVersion: { integerValue: '1' },
      state: { stringValue: JSON.stringify(state) },
    } }),
  });
  assert.equal(seed.status, 200);

  const requests = [];
  let transaction;
  const client = {
    async request(request) {
      requests.push(structuredClone(request));
      const source = new URL(request.url);
      if (request.method === 'GET') {
        assert.equal(source.searchParams.get('transaction'), transaction);
      }
      // O Emulator 1.22 não mapeia BYTE_STRING no query param REST; a asserção
      // acima preserva o contrato e somente o transporte local omite esse valor.
      const search = request.method === 'GET' ? '' : source.search;
      const response = await fetch(`http://${emulator}${source.pathname}${search}`, {
        method: request.method,
        headers: {
          Authorization: authorization,
          ...(request.data === undefined ? {} : { 'Content-Type': 'application/json' }),
        },
        body: request.data === undefined ? undefined : JSON.stringify(request.data),
      });
      const data = await response.json();
      if (!response.ok) {
        const error = new Error('emulator_request_failed');
        error.response = { status: response.status, data };
        throw error;
      }
      if (request.url.endsWith('/documents:beginTransaction')) transaction = data.transaction;
      return { status: response.status, data };
    },
  };
  const store = new NamedDatabaseAssistantCostLedgerStore({
    authFactory: () => ({ getClient: async () => client, getProjectId: async () => projectId }),
  });

  assert.deepEqual(await store.runTransaction(() => ({ accepted: true })), { accepted: true });
  assert.deepEqual(requests[0].data, {});
  assert.equal(requests[1].url.includes(`transaction=${encodeURIComponent(transaction)}`), true);
  assert.equal(requests[2].data.transaction, transaction);
  assert.equal(requests[2].data.writes.length, 1);
  assert.equal(
    requests[2].data.writes[0].update.name,
    `projects/${projectId}/databases/${databaseId}/documents/assistantRuntime/ledger`,
  );
});
