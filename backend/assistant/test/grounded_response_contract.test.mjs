import assert from 'node:assert/strict';
import test from 'node:test';

import {
  admitGroundedAssistantResponse,
  AssistantAuthorizedContextAssembler,
  assessDevelopmentAssistantActivationReadiness,
} from '../src/index.mjs';

const period = Object.freeze({ timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-09-02' });
const fact = Object.freeze({
  evidenceId: 'ev_accounts_001', source: 'accounts', kind: 'moneyCentsBrl', value: 125000,
  civilPeriod: period, evidence: { alias: 'ev_accounts_001', source: 'accounts', period },
});
const context = Object.freeze({
  ownerVerified: true, isFromServer: true, hasPendingWrites: false,
  generatedAt: '2026-09-02T03:00:00.000Z', civilPeriod: period,
  technicalWindow: { start: '2026-09-01T03:00:00.000Z', endExclusive: '2026-09-02T03:00:00.000Z' },
  availableDataWindow: { start: '2026-09-01T03:00:00.000Z', endExclusive: '2026-09-02T03:00:00.000Z' },
  periodComplete: true,
  facts: [fact], missingSources: [],
});
const response = Object.freeze({
  schemaVersion: 1, status: 'grounded', answer: 'Resumo confirmado.',
  assertions: [{ statement: 'O saldo confirmado é 125000 centavos.', evidence: fact.evidence }],
  missingData: [], disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
});

test('admite resposta fundamentada somente por alias, fonte e período confirmados', () => {
  const admission = admitGroundedAssistantResponse({ response, context });
  assert.equal(admission.finalStatus, 'grounded');
  assert.equal(admission.response.status, 'grounded');
  assert.equal('reason' in admission, false);
});

for (const [name, altered, reason] of [
  ['sem evidência', { ...response, assertions: [{ statement: 'Resumo confirmado.' }] }, 'assertion_shape_invalid'],
  ['fonte inválida', { ...response, assertions: [{ ...response.assertions[0], evidence: { ...fact.evidence, source: 'transactions' } }] }, 'evidence_source_mismatch'],
  ['período inválido', { ...response, assertions: [{ ...response.assertions[0], evidence: { ...fact.evidence, period: { ...period, timeZone: 'UTC' } } }] }, 'evidence_period_invalid'],
  ['número sem evidência', { ...response, assertions: [{ ...response.assertions[0], statement: 'O saldo confirmado é 999 centavos.' }] }, 'assertion_value_ungrounded'],
  ['recomendação', { ...response, assertions: [{ ...response.assertions[0], statement: 'Compre agora por 125000 centavos.' }] }, 'assertion_text_unsafe'],
  ['identidade', { ...response, answer: 'Contate pessoa@exemplo.com.' }, 'response_text_unsafe'],
]) {
  test(`falha fechada com ${name}`, () => {
    const admission = admitGroundedAssistantResponse({ response: altered, context });
    assert.equal(admission.finalStatus, 'safe_unavailable');
    assert.equal(admission.reason, reason);
    assert.equal(admission.response.assertions.length, 0);
  });
}

test('classifica ausência legítima e falha de interpretação sem promover resposta', () => {
  const insufficient = admitGroundedAssistantResponse({
    response: {
      schemaVersion: 1,
      status: 'safe_unavailable',
      answer: 'Não há dados confirmados suficientes para responder com segurança.',
      assertions: [],
      missingData: ['confirmed_financial_evidence'],
      disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
    },
    context,
  });
  assert.equal(insufficient.finalStatus, 'safe_unavailable');
  assert.equal(insufficient.reason, 'provider_reported_insufficient_evidence');

  const invalidJson = admitGroundedAssistantResponse({
    response: null,
    context,
    providerOutputIssue: 'provider_output_invalid_json',
  });
  assert.equal(invalidJson.finalStatus, 'safe_unavailable');
  assert.equal(invalidJson.reason, 'provider_output_invalid_json');
});

test('monta contexto somente após admissão e sem expor identidade na saída', async () => {
  let reads = 0;
  const assembler = new AssistantAuthorizedContextAssembler({
    bridge: {
      async buildOwnConfirmedContext({ actor, period: receivedPeriod }) {
        reads += 1;
        assert.equal(actor.uid, 'synthetic-owner');
        assert.deepEqual(receivedPeriod, period);
        return context;
      },
    },
  });
  const authorization = {
    authenticated: true, uid: 'synthetic-owner', requestedOwnerId: 'synthetic-owner', appCheckVerified: true,
    emailVerified: true, legalProfileVerified: true, aiConsentEnabled: true, profileFromServer: true,
    profileHasPendingWrites: false, acceptedPolicyVersion: 'assist-context-v1', aiConsentUpdatedAt: '2026-09-01T03:00:00.000Z',
    financialPrivacyActive: false,
  };
  const scope = { kind: 'own_financial_information', sources: ['accounts'] };
  const assembled = await assembler.assemble({ authorization, civilPeriod: period, scope });
  assert.equal(reads, 1);
  assert.doesNotMatch(JSON.stringify(assembled), /synthetic-owner|uid|email/i);
  await assert.rejects(
    assembler.assemble({ authorization: { ...authorization, financialPrivacyActive: true }, civilPeriod: period, scope }),
    /assistant_financial_privacy_active/,
  );
  assert.equal(reads, 1);
});

test('prontidão mantém kill switch, flag desligada, ledger e roteamento backend-only', () => {
  const result = assessDevelopmentAssistantActivationReadiness({
    prerequisites: {
      runtimeIdentityValidated: true, secretManagerValidated: true, appCheckValidated: true,
      consentValidated: true, rollbackValidated: true,
    },
  });
  assert.deepEqual(result, {
    allowed: false, reason: 'kill_switch_active', pending: [], defaultTier: 'flash', proEscalation: 'backend_only',
    dailyLimitCents: 500, monthlyOperationalLimitCents: 4500,
  });
});
