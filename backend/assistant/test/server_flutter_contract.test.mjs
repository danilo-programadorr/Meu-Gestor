/**
 * Intenção: prova o contrato consumido pelo Flutter com callable, admissão e
 * quota reais; somente autorização, contexto e provedor externos são simulados.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  AssistantCostControlLedger,
  InMemoryAssistantCostLedgerStore,
  createAssistRemoteV1Callables,
  createAssistantOwnerScope,
} from '../src/index.mjs';

const fixturePath = new URL('../../../test/fixtures/assistant_server_flutter_contract.json', import.meta.url);
const fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
const ownerUid = 'synthetic-owner';
const ownerScope = createAssistantOwnerScope(ownerUid);
const now = new Date('2026-09-02T04:00:00.000Z');
const period = Object.freeze({
  timeZone: 'America/Sao_Paulo',
  startDate: '2026-09-01',
  endDateExclusive: '2026-09-02',
});
const context = Object.freeze({
  ownerVerified: true,
  isFromServer: true,
  hasPendingWrites: false,
  generatedAt: now.toISOString(),
  civilPeriod: period,
  technicalWindow: Object.freeze({
    start: '2026-09-01T03:00:00.000Z',
    endExclusive: '2026-09-02T03:00:00.000Z',
  }),
  availableDataWindow: Object.freeze({
    start: '2026-09-01T03:00:00.000Z',
    endExclusive: '2026-09-02T03:00:00.000Z',
  }),
  periodComplete: true,
  facts: Object.freeze([Object.freeze({
    evidenceId: 'saldo_confirmado',
    source: 'dashboardSummary',
    kind: 'moneyCentsBrl',
    value: 75000,
    civilPeriod: period,
    evidence: Object.freeze({ alias: 'saldo_confirmado', source: 'dashboardSummary', period }),
  })]),
  missingSources: Object.freeze([]),
});

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const authorization = Object.freeze({
  legalProfileVerified: true,
  aiConsentEnabled: true,
  profileFromServer: true,
  profileHasPendingWrites: false,
  acceptedPolicyVersion: 'assist-context-v1',
  aiConsentUpdatedAt: '2026-09-01T03:00:00.000Z',
  financialPrivacyActive: false,
});

// Cada caso começa com uso não zero e usa o ledger real para reservar e
// confirmar a mesma quota que protege a composição implantada.
const invokeCase = async (contractCase) => {
  const store = new InMemoryAssistantCostLedgerStore({
    daily: {}, monthly: {}, periods: {}, records: {},
    usage: {
      [ownerScope]: { windowDay: '2026-09-02', costUnitsInWindow: 3, proCallsInWindow: 0 },
    },
  });
  const ledger = new AssistantCostControlLedger({ store, clock: () => new Date(now) });
  const events = [];
  const callable = createAssistRemoteV1Callables({
    onCall: (_options, handler) => handler,
    HttpsError: FakeHttpsError,
    authorizationReader: async () => authorization,
    contextReader: async () => context,
    usageReader: async () => ledger.readUsage({ ownerScope }),
    ledger,
    providerGateway: { generate: async () => structuredClone(contractCase.providerResult) },
    runtimeControlsReader: () => ({ killSwitchActive: false, providerFeatureEnabled: true }),
    runtimeDiagnostics: { report: (event) => events.push(event) },
  }).assistRemoteV1;

  const response = await callable({
    data: {
      contractVersion: fixture.contractVersion,
      message: 'Explique o resumo confirmado com segurança.',
    },
    auth: { uid: ownerUid, token: { email_verified: true } },
    app: {},
    rawRequest: { headers: { authorization: 'Bearer synthetic.owner.authorization.for.contract.test' } },
  });
  return { response, events, snapshot: store.snapshot() };
};

for (const contractCase of fixture.cases) {
  test(`callable entrega ao Flutter o caso ${contractCase.name}`, async () => {
    const { response, events, snapshot } = await invokeCase(contractCase);
    assert.deepEqual(response, contractCase.expectedResponse);
    const finalEvent = events.at(-1);
    assert.equal(finalEvent.stage, 'response_validation');
    assert.equal(finalEvent.outcome, 'passed');
    assert.equal(finalEvent.finalStatus, contractCase.expectedFinalStatus);
    assert.equal(finalEvent.reason ?? null, contractCase.expectedReason);
    assert.equal(Object.values(snapshot.records).length, 1);
    assert.equal(Object.values(snapshot.records)[0].state, 'confirmed');
  });
}
