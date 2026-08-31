import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_FLUTTER_CONTRACT_VERSION,
  ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  assertSanitizedAssistantOperationalMetric,
  prepareAssistantRemoteActivation,
} from '../src/index.mjs';
import { AssistantContractError } from '../src/errors.mjs';

const authorization = (overrides = {}) => ({
  authenticated: true,
  uid: 'own-user',
  requestedOwnerId: 'own-user',
  appCheckVerified: true,
  emailVerified: true,
  legalProfileVerified: true,
  aiConsentEnabled: true,
  profileFromServer: true,
  profileHasPendingWrites: false,
  acceptedPolicyVersion: 'assist-context-v1',
  aiConsentUpdatedAt: '2026-08-30T00:00:00.000Z',
  ...overrides,
});

const context = () => ({
  isFromServer: true,
  hasPendingWrites: false,
  ownerVerified: true,
  generatedAt: '2026-08-30T00:00:00.000Z',
  period: { start: '2026-08-01T00:00:00.000Z', end: '2026-08-30T00:00:00.000Z' },
  facts: [{ evidenceId: 'saldo_confirmado', source: 'dashboardSummary', kind: 'moneyCentsBrl', value: 75000 }],
  missingSources: [],
});

const usage = () => ({ costUnitsInWindow: 0, proCallsInWindow: 0 });

test('contrato Flutter aceita somente versão e mensagem sem identidade ou contexto', () => {
  assert.throws(
    () => prepareAssistantRemoteActivation({
      flutterRequest: { contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION, message: 'Resumo', uid: 'other-user' },
      authorization: authorization(), context: context(), usage: usage(),
    }),
    /assistant_flutter_contract_invalid/,
  );
});

test('consentimento e contexto confirmado são validados antes da decisão de tier', () => {
  assert.throws(
    () => prepareAssistantRemoteActivation({
      flutterRequest: { contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION, message: 'Resumo' },
      authorization: authorization({ aiConsentEnabled: false }), context: context(), usage: usage(),
    }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_consent_required',
  );
});

test('servidor decide Flash, mas kill switch bloqueia toda execução remota', () => {
  const plan = prepareAssistantRemoteActivation({
    flutterRequest: { contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION, message: 'Resumo confirmado' },
    authorization: authorization(), context: context(), usage: usage(),
  });
  assert.equal(ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE, true);
  assert.deepEqual(plan, {
    contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
    tier: 'flash', maxInputUnits: 2500, maxOutputUnits: 800,
    allowed: false, disabledReason: 'kill_switch_active',
  });
});

test('Pro é decidido somente pelo servidor e continua bloqueado sem provedor real', () => {
  const plan = prepareAssistantRemoteActivation({
    flutterRequest: {
      contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
      message: 'Compare cenários com múltiplas fontes e múltiplas hipóteses.',
    },
    authorization: authorization(), context: context(), usage: usage(), killSwitchActive: false,
  });
  assert.equal(plan.tier, 'pro');
  assert.equal(plan.allowed, false);
  assert.equal(plan.disabledReason, 'provider_feature_disabled');
});

test('métrica operacional não aceita prompt, resposta, identidade ou valores', () => {
  assert.deepEqual(
    assertSanitizedAssistantOperationalMetric({ durationMs: 20, result: 'blocked', tier: 'flash' }),
    { durationMs: 20, result: 'blocked', tier: 'flash' },
  );
  assert.throws(
    () => assertSanitizedAssistantOperationalMetric({ durationMs: 20, result: 'blocked', tier: 'flash', prompt: 'nunca registrar' }),
    /assistant_operational_metric_invalid/,
  );
});
