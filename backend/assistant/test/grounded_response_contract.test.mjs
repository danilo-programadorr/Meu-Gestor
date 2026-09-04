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
  facts: [fact], missingSources: [],
});
const response = Object.freeze({
  schemaVersion: 1, status: 'grounded', answer: 'Resumo confirmado.',
  assertions: [{ statement: 'O saldo confirmado é 125000 centavos.', evidence: fact.evidence }],
  missingData: [], disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
});

test('admite resposta fundamentada somente por alias, fonte e período confirmados', () => {
  assert.equal(admitGroundedAssistantResponse({ response, context }).status, 'grounded');
});

for (const [name, altered] of [
  ['sem evidência', { ...response, assertions: [{ statement: 'Resumo confirmado.' }] }],
  ['fonte inválida', { ...response, assertions: [{ ...response.assertions[0], evidence: { ...fact.evidence, source: 'transactions' } }] }],
  ['período inválido', { ...response, assertions: [{ ...response.assertions[0], evidence: { ...fact.evidence, period: { ...period, timeZone: 'UTC' } } }] }],
  ['número sem evidência', { ...response, assertions: [{ ...response.assertions[0], statement: 'O saldo confirmado é 999 centavos.' }] }],
  ['recomendação', { ...response, assertions: [{ ...response.assertions[0], statement: 'Compre agora por 125000 centavos.' }] }],
  ['identidade', { ...response, answer: 'Contate pessoa@exemplo.com.' }],
]) {
  test(`falha fechada com ${name}`, () => {
    const result = admitGroundedAssistantResponse({ response: altered, context });
    assert.equal(result.status, 'safe_unavailable');
    assert.equal(result.assertions.length, 0);
  });
}

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
