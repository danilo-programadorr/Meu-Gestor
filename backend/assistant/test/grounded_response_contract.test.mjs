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
  assertions: [{ statement: 'O saldo confirmado é R$ 1.250,00.', evidence: fact.evidence }],
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
  ['número divergente', { ...response, assertions: [{ ...response.assertions[0], statement: 'O saldo confirmado é R$ 9,99.' }] }, 'assertion_numeric_value_mismatch'],
  ['recomendação', { ...response, assertions: [{ ...response.assertions[0], statement: 'Compre agora por R$ 1.250,00.' }] }, 'assertion_text_unsafe'],
  ['identidade', { ...response, answer: 'Contate pessoa@exemplo.com.' }, 'response_text_unsafe'],
]) {
  test(`falha fechada com ${name}`, () => {
    const admission = admitGroundedAssistantResponse({ response: altered, context });
    assert.equal(admission.finalStatus, 'safe_unavailable');
    assert.equal(admission.reason, reason);
    assert.equal(admission.response.assertions.length, 0);
  });
}

const admissionForFact = ({
  kind,
  value,
  statement,
  answer = 'Resumo confirmado.',
  disclaimer = 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
}) => {
  const typedFact = Object.freeze({ ...fact, kind, value });
  return admitGroundedAssistantResponse({
    context: { ...context, facts: [typedFact] },
    response: {
      ...response,
      answer,
      disclaimer,
      assertions: [{ statement, evidence: typedFact.evidence }],
    },
  });
};

for (const [name, input, expectedStatement] of [
  ['BRL com milhar e centavos', { kind: 'moneyCentsBrl', value: 125000, statement: 'Saldo de R$ 1.250,00.' }, 'Saldo de R$ 1.250,00.'],
  ['BRL decimal equivalente', { kind: 'moneyCentsBrl', value: 125000, statement: 'Saldo de R$ 1250,0.' }, 'Saldo de R$ 1.250,00.'],
  ['BRL negativo', { kind: 'moneyCentsBrl', value: -4500, statement: 'Resultado de -45 reais.' }, 'Resultado de -R$ 45,00.'],
  ['contagem inteira', { kind: 'integer', value: 12, statement: 'Há 12 contas confirmadas.' }, 'Há 12 contas confirmadas.'],
  ['pontos-base como percentual', { kind: 'basisPoints', value: 150, statement: 'A taxa é 1,50%.' }, 'A taxa é 1,50%.'],
  ['pontos-base negativos', { kind: 'basisPoints', value: -25, statement: 'A variação é -25 pontos-base.' }, 'A variação é -25 pontos-base.'],
  ['data civil brasileira', { kind: 'civilDate', value: '2026-09-20', statement: 'A data confirmada é 20/09/2026.' }, 'A data confirmada é 20/09/2026.'],
  ['instante como data civil de São Paulo', { kind: 'utcInstant', value: '2026-09-20T03:00:00.000Z', statement: 'O vencimento é 20/09/2026.' }, 'O vencimento é 20/09/2026.'],
]) {
  test(`admite equivalência semântica exata para ${name}`, () => {
    const admission = admissionForFact(input);
    assert.equal(admission.finalStatus, 'grounded');
    assert.equal(admission.response.assertions[0].statement, expectedStatement);
  });
}

for (const [name, input, reason] of [
  ['valor financeiro diferente', { kind: 'moneyCentsBrl', value: 125000, statement: 'Saldo de R$ 1.249,99.' }, 'assertion_numeric_value_mismatch'],
  ['sinal financeiro trocado', { kind: 'moneyCentsBrl', value: -4500, statement: 'Resultado de R$ 45,00.' }, 'assertion_numeric_value_mismatch'],
  ['contagem extra em evidência monetária', { kind: 'moneyCentsBrl', value: 125000, statement: 'Saldo de R$ 1.250,00 em 2 contas.' }, 'assertion_numeric_value_mismatch'],
  ['notação numérica sem unidade compatível', { kind: 'integer', value: 1, statement: 'Há 1e1 item confirmado.' }, 'assertion_numeric_value_mismatch'],
  ['percentual com precisão incompatível', { kind: 'basisPoints', value: 150, statement: 'A taxa é 1,499%.' }, 'assertion_numeric_value_mismatch'],
  ['data diferente', { kind: 'civilDate', value: '2026-09-20', statement: 'A data confirmada é 21/09/2026.' }, 'assertion_numeric_value_mismatch'],
  ['número ligado a texto não numérico', { kind: 'safeLabel', value: 'Conta principal', statement: 'Há 2 itens confirmados.' }, 'assertion_evidence_non_numeric'],
]) {
  test(`rejeita ${name}`, () => {
    const admission = admissionForFact(input);
    assert.equal(admission.finalStatus, 'safe_unavailable');
    assert.equal(admission.reason, reason);
  });
}

test('valida e renderiza conjuntamente answer e afirmações a partir do fato financeiro', () => {
  const admission = admissionForFact({
    kind: 'moneyCentsBrl',
    value: 125000,
    statement: 'Saldo de 125000 centavos.',
    answer: 'O saldo confirmado é R$ 1250,0.',
  });
  assert.equal(admission.finalStatus, 'grounded');
  assert.equal(admission.response.answer, 'O saldo confirmado é R$ 1.250,00.');
  assert.equal(admission.response.assertions[0].statement, 'Saldo de R$ 1.250,00.');
});

test('rejeita número inventado no answer mesmo quando a afirmação está fundamentada', () => {
  const admission = admissionForFact({
    kind: 'moneyCentsBrl',
    value: 125000,
    statement: 'Saldo de R$ 1.250,00.',
    answer: 'O saldo confirmado é R$ 1.300,00.',
  });
  assert.equal(admission.finalStatus, 'safe_unavailable');
  assert.equal(admission.reason, 'answer_numeric_value_mismatch');
});

test('distingue answer numérico sem nenhuma evidência de grandeza comparável', () => {
  const admission = admissionForFact({
    kind: 'safeLabel',
    value: 'Conta principal',
    statement: 'A conta principal está confirmada.',
    answer: 'Há 2 itens confirmados.',
  });
  assert.equal(admission.finalStatus, 'safe_unavailable');
  assert.equal(admission.reason, 'answer_evidence_non_numeric');
});

test('rejeita grandeza inventada no disclaimer visível', () => {
  const admission = admissionForFact({
    kind: 'moneyCentsBrl',
    value: 125000,
    statement: 'Saldo de R$ 1.250,00.',
    disclaimer: 'Conteúdo informativo com referência de R$ 1.300,00.',
  });
  assert.equal(admission.finalStatus, 'safe_unavailable');
  assert.equal(admission.reason, 'disclaimer_numeric_value_mismatch');
});

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
