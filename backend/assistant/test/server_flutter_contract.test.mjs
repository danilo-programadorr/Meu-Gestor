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
  createVertexRuntimeGateway,
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

const readyPlanEnvelope = Object.freeze({
  candidates: [Object.freeze({
    finishReason: 'STOP',
    content: Object.freeze({ parts: [Object.freeze({ text: JSON.stringify({
      schemaVersion: 1,
      status: 'ready',
      intent: 'balance',
      clarificationCode: 'none',
      periodCode: 'today',
      financialTool: 'balance',
    }) })] }),
  })],
});

const vertexFactoryFor = (answerEnvelope) => {
  let invocation = 0;
  return async () => ({
    models: {
      generateContent: async () => {
        invocation += 1;
        return invocation === 1 ? readyPlanEnvelope : answerEnvelope;
      },
    },
  });
};

// Cada caso começa com uso não zero e usa o ledger real para reservar e
// confirmar a mesma quota que protege a composição implantada.
const invokeCase = async (contractCase, providerGateway = undefined) => {
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
    providerGateway: providerGateway ?? {
      plan: async () => ({
        plan: contractCase.name === 'clarification_required'
          ? {
              schemaVersion: 1, status: 'clarification_required', intent: 'financial_overview',
              clarificationCode: 'period_required', periodCode: 'none', financialTool: 'none',
            }
          : {
              schemaVersion: 1, status: 'ready', intent: 'balance', clarificationCode: 'none',
              periodCode: 'today', financialTool: 'balance',
            },
        durationMs: 10,
        confirmedCostCents: 7,
        providerDiagnostics: { finishReason: 'STOP' },
      }),
      generate: async () => structuredClone(contractCase.providerResult),
    },
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
    const records = Object.values(snapshot.records);
    assert.equal(records.length, contractCase.name === 'clarification_required' ? 1 : 2);
    assert.ok(records.every((record) => record.state === 'confirmed'));
    assert.equal(
      snapshot.usage[ownerScope].costUnitsInWindow,
      contractCase.name === 'clarification_required' ? 4 : 5,
    );
  });
}

// Percorre o envelope real do SDK, a extração, a admissão e a resposta pública
// consumida pelo Flutter, sem rede ou conteúdo financeiro real.
test('SDK unary completo chega grounded ao contrato Flutter', async () => {
  const groundedCase = fixture.cases.find((item) => item.name === 'grounded');
  const providerEnvelope = structuredClone(groundedCase.providerResult.response);
  delete providerEnvelope.answer;
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    clock: (() => { let value = 100; return () => (value += 25); })(),
    vertexAiFactory: vertexFactoryFor({
      candidates: [{
        finishReason: 'STOP',
        content: { parts: [{ text: JSON.stringify(providerEnvelope) }] },
      }],
    }),
  });
  const { response, events } = await invokeCase(groundedCase, gateway);
  assert.deepEqual(response, groundedCase.expectedResponse);
  assert.equal(events.at(-1).finalStatus, 'grounded');
});

test('SDK não aceita answer livre do provedor fora do schema autoritativo', async () => {
  const groundedCase = fixture.cases.find((item) => item.name === 'grounded');
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: vertexFactoryFor({
      candidates: [{
        finishReason: 'STOP',
        content: { parts: [{ text: JSON.stringify(groundedCase.providerResult.response) }] },
      }],
    }),
  });
  const { response, events } = await invokeCase(groundedCase, gateway);
  assert.equal(response.status, 'safe_unavailable');
  assert.equal(events.at(-1).reason, 'provider_output_schema_invalid');
});

test('SDK truncado por tokens permanece indisponível no contrato Flutter', async () => {
  const fallbackCase = fixture.cases.find((item) => item.name === 'invalid_model_output');
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: vertexFactoryFor({
      candidates: [{
        finishReason: 'MAX_TOKENS',
        content: { parts: [{ text: '{"schemaVersion":1' }] },
      }],
    }),
  });
  const { response, events } = await invokeCase(fallbackCase, gateway);
  assert.deepEqual(response, fallbackCase.expectedResponse);
  assert.equal(events.at(-1).finalStatus, 'safe_unavailable');
  assert.equal(events.at(-1).reason, 'provider_output_max_tokens');
});
