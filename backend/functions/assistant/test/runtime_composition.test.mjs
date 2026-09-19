/**
 * Intenção: exercita a composição real de autorização, contexto, uso e
 * reserva transacional com somente as bordas externas simuladas.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_FLUTTER_CONTRACT_VERSION,
  InMemoryAssistantCostLedgerStore,
  createAssistRemoteV1Callables,
  createAssistantOwnerScope,
} from '../shared/index.mjs';
import { createAssistantRuntimeAdapters } from '../src/runtime_adapters.mjs';
import { createAssistantRuntimeLedger } from '../src/runtime_ledger.mjs';
import { createAssistantRuntimeUsageReader } from '../src/runtime_usage_reader.mjs';

const projectId = 'demo-assistant-controls';
const ownerUid = 'synthetic-owner';
const now = new Date('2026-09-13T15:30:00.000Z');
const string = (value) => ({ stringValue: value });
const integer = (value) => ({ integerValue: String(value) });
const boolean = (value) => ({ booleanValue: value });
const timestamp = (value) => ({ timestampValue: value });

const document = (collection, id, fields) => ({
  name: `projects/${projectId}/databases/(default)/documents/users/${ownerUid}/${collection}/${id}`,
  fields: { ownerId: string(ownerUid), ...fields },
});

// As respostas simulam o protocolo Firestore; os leitores e validadores reais
// continuam responsáveis por derivar e admitir cada fato.
const collectionDocuments = Object.freeze({
  accounts: [document('accounts', 'account_1', {
    openingBalanceCents: integer(125000), currencyCode: string('BRL'),
    includeInTotal: boolean(true), isArchived: boolean(false),
  })],
  transactions: [
    document('transactions', 'confirmed_1', {
      kind: string('income'), amountCents: integer(90000), isVoided: boolean(false),
      occurredAt: timestamp('2026-09-13T12:00:00.000Z'),
    }),
    document('transactions', 'future_1', {
      kind: string('expense'), amountCents: integer(99999), isVoided: boolean(false),
      occurredAt: timestamp('2026-09-13T16:30:00.000Z'),
    }),
  ],
  payables: [],
  receivables: [],
  investmentPortfolios: [],
  investmentAssets: [],
  investmentOperations: [],
  investmentIncomeEvents: [],
});

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

test('composição real admite pergunta comum, hoje parcial, uso não zero e reserva de quota', async () => {
  const fetchImpl = async (url) => {
    if (url.includes('/assistantSettings/remote?')) {
      return { ok: true, json: async () => ({ fields: {
        consentVersion: string('assist-context-v1'),
        financialContextAllowed: boolean(true),
        updatedAt: timestamp('2026-09-13T10:00:00.000Z'),
      } }) };
    }
    if (url.includes(`/documents/users/${ownerUid}?`)) {
      return { ok: true, json: async () => ({ fields: {
        ownerId: string(ownerUid), emailVerifiedSnapshot: boolean(true),
        termsVersionAccepted: string('terms-dev-1.0.0'),
        privacyVersionAccepted: string('privacy-dev-1.0.0'),
        aiConsentEnabled: boolean(true),
        aiConsentUpdatedAt: timestamp('2026-09-13T10:00:00.000Z'),
      } }) };
    }
    const collection = /\/documents\/users\/[^/]+\/([^?]+)/u.exec(url)?.[1];
    assert.ok(collection in collectionDocuments);
    return { ok: true, json: async () => ({ documents: collectionDocuments[collection] }) };
  };
  const runtimeAdapters = createAssistantRuntimeAdapters({
    authFactory: () => ({ getProjectId: async () => projectId }),
    fetchImpl,
    clock: () => new Date(now),
  });
  const ownerScope = createAssistantOwnerScope(ownerUid);
  const store = new InMemoryAssistantCostLedgerStore({
    daily: {}, monthly: {}, periods: {}, records: {},
    usage: { [ownerScope]: { windowDay: '2026-09-13', costUnitsInWindow: 3, proCallsInWindow: 0 } },
  });
  const ledger = createAssistantRuntimeLedger({ store, clock: () => new Date(now) });
  let providerContext;
  const stages = [];
  const providerGateway = {
    async generate({ providerRequest }) {
      providerContext = providerRequest.context;
      const evidence = providerRequest.context.facts[0].evidence;
      return {
        response: {
          schemaVersion: 1, status: 'grounded', answer: 'Resumo confirmado.',
          assertions: [{ statement: 'Há dados confirmados no período.', evidence }], missingData: [],
          disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
        },
        durationMs: 25,
        confirmedCostCents: 7,
      };
    },
  };
  const callables = createAssistRemoteV1Callables({
    onCall: (_options, handler) => handler,
    HttpsError: FakeHttpsError,
    ...runtimeAdapters,
    usageReader: createAssistantRuntimeUsageReader({ ledger }),
    ledger,
    providerGateway,
    runtimeControlsReader: () => ({ killSwitchActive: false, providerFeatureEnabled: true }),
    runtimeDiagnostics: { report: (event) => stages.push(event) },
  });

  let result;
  try {
    result = await callables.assistRemoteV1({
      data: {
        contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
        message: 'Explique meu resumo financeiro.',
      },
      auth: { uid: ownerUid, token: { email_verified: true } },
      app: {},
      rawRequest: { headers: { authorization: 'Bearer synthetic.owner.authorization.for.integration.test' } },
    });
  } catch (error) {
    assert.fail(`falha na composição após ${JSON.stringify(stages)}: ${error.code}`);
  }

  assert.equal(result.status, 'grounded');
  assert.equal(providerContext.civilPeriod.startDate, '2026-09-13');
  assert.equal(providerContext.periodComplete, false);
  assert.equal(providerContext.availableDataWindow.endExclusive, now.toISOString());
  const transactionFacts = providerContext.facts.filter((fact) => fact.source === 'transactions');
  assert.deepEqual(transactionFacts.map((fact) => fact.value), [90000, -0]);
  const snapshot = store.snapshot();
  assert.equal(snapshot.usage[ownerScope].costUnitsInWindow, 11);
  assert.equal(Object.values(snapshot.records).length, 1);
  assert.equal(Object.values(snapshot.records)[0].state, 'confirmed');
  assert.equal(snapshot.daily['2026-09-13'].confirmedCostCents, 7);
  assert.deepEqual(stages.slice(-10), [
    { stage: 'activation_plan', outcome: 'started' },
    { stage: 'activation_plan', outcome: 'passed' },
    { stage: 'ledger_reserve', outcome: 'started' },
    { stage: 'ledger_reserve', outcome: 'passed' },
    { stage: 'vertex_model', outcome: 'started' },
    { stage: 'vertex_model', outcome: 'passed' },
    { stage: 'ledger_confirm', outcome: 'started' },
    { stage: 'ledger_confirm', outcome: 'passed' },
    { stage: 'response_validation', outcome: 'started' },
    { stage: 'response_validation', outcome: 'passed' },
  ]);
});
