import assert from 'node:assert/strict';
import test from 'node:test';

import { ASSISTANT_POLICY_VERSION, AssistantContractError, AssistantModelRouter, AssistantService } from '../src/index.mjs';

const authorization = (overrides = {}) => ({
  authenticated: true,
  appCheckVerified: true,
  emailVerified: true,
  legalProfileVerified: true,
  uid: 'own-user',
  requestedOwnerId: 'own-user',
  aiConsentEnabled: true,
  acceptedPolicyVersion: ASSISTANT_POLICY_VERSION,
  aiConsentUpdatedAt: '2026-08-24T12:00:00.000Z',
  profileFromServer: true,
  profileHasPendingWrites: false,
  isOwner: false,
  ...overrides,
});

const context = (overrides = {}) => ({
  ownerVerified: true,
  isFromServer: true,
  hasPendingWrites: false,
  generatedAt: '2026-08-24T12:00:00.000Z',
  period: { start: '2026-08-01T03:00:00.000Z', end: '2026-08-24T12:00:00.000Z' },
  facts: [{ evidenceId: 'monthly_income', source: 'transactions', kind: 'moneyCentsBrl', value: 250000 }],
  missingSources: ['budgets', 'projectedBalance'],
  ...overrides,
});

const response = (overrides = {}) => ({
  schemaVersion: 1,
  answer: 'As receitas confirmadas no período somam o valor informado.',
  observations: [{ statement: 'Há receita confirmada no período.', evidenceIds: ['monthly_income'] }],
  missingData: ['budgets', 'projectedBalance'],
  proposedActions: [],
  disclaimer: 'Conteúdo informativo; revise os dados antes de decidir.',
  ...overrides,
});

const createHarness = ({ contextValue = context(), providerResponse = response() } = {}) => {
  const calls = { context: 0, provider: 0, request: null };
  return {
    calls,
    service: new AssistantService({
      contextRepository: {
        async readOwnConfirmedContext(uid) {
          calls.context += 1;
          assert.equal(uid, 'own-user');
          return contextValue;
        },
      },
      providerGateway: {
        async generate(request) {
          calls.provider += 1;
          calls.request = request;
          return providerResponse;
        },
      },
      modelRouter: new AssistantModelRouter(),
      usageRepository: {
        async readOwnWindow(uid) {
          assert.equal(uid, 'own-user');
          return { costUnitsInWindow: 0, proCallsInWindow: 0 };
        },
      },
    }),
  };
};

const rejectsCode = async (promise, code) => {
  await assert.rejects(promise, (error) => error instanceof AssistantContractError && error.code === code);
};

test('monta contexto próprio minimizado e não oferece mutação ao provedor', async () => {
  const harness = createHarness();
  const result = await harness.service.ask({ clientRequest: { message: 'Como estão minhas receitas?' }, authorization: authorization() });
  assert.equal(result.schemaVersion, 1);
  assert.equal(harness.calls.provider, 1);
  assert.equal(harness.calls.request.memoryMode, 'none');
  assert.equal(harness.calls.request.responseContract.mutationsAllowed, false);
  assert.equal(harness.calls.request.routing.tier, 'flash');
  const serialized = JSON.stringify(harness.calls.request);
  assert.doesNotMatch(serialized, /own-user|uid|email|token|ownerId/);
});

for (const [name, override, code] of [
  ['autenticação', { authenticated: false }, 'assistant_unauthenticated'],
  ['App Check', { appCheckVerified: false }, 'assistant_app_check_required'],
  ['e-mail', { emailVerified: false }, 'assistant_email_not_verified'],
  ['perfil jurídico', { legalProfileVerified: false }, 'assistant_legal_profile_required'],
  ['consentimento', { aiConsentEnabled: false }, 'assistant_consent_required'],
  ['política atual', { acceptedPolicyVersion: 'old-policy' }, 'assistant_consent_version_outdated'],
]) {
  test(`falha fechada sem ${name}`, async () => {
    const harness = createHarness();
    await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro' }, authorization: authorization(override) }), code);
    assert.deepEqual(harness.calls, { context: 0, provider: 0, request: null });
  });
}

test('owner não contorna isolamento por UID', async () => {
  const harness = createHarness();
  await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro' }, authorization: authorization({ requestedOwnerId: 'other-user', isOwner: true }) }), 'assistant_owner_mismatch');
  assert.equal(harness.calls.context, 0);
});

test('cliente não pode enviar UID nem contexto financeiro', async () => {
  const harness = createHarness();
  await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro', uid: 'other-user' }, authorization: authorization() }), 'assistant_invalid_request');
  assert.equal(harness.calls.context, 0);
});

for (const unsafe of ['contato terceiro@exemplo.com', 'senha: segredo', 'token=abc', 'CPF 123.456.789-01']) {
  test('bloqueia segredo ou dado pessoal no texto', async () => {
    const harness = createHarness();
    await rejectsCode(harness.service.ask({ clientRequest: { message: unsafe }, authorization: authorization() }), 'assistant_unsafe_content');
    assert.equal(harness.calls.provider, 0);
  });
}

test('não usa contexto de cache nem com escrita pendente', async () => {
  const harness = createHarness({ contextValue: context({ isFromServer: false, hasPendingWrites: true }) });
  await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro' }, authorization: authorization() }), 'assistant_invalid_context');
  assert.equal(harness.calls.provider, 0);
});

test('recusa fonte, tipo e lacuna fora dos catálogos fechados', async () => {
  for (const contextValue of [
    context({ facts: [{ evidenceId: 'unknown_fact', source: 'privateDirectory', kind: 'integer', value: 1 }] }),
    context({ facts: [{ evidenceId: 'invalid_fact', source: 'accounts', kind: 'floatingMoney', value: 1 }] }),
    context({ missingSources: ['accounts'] }),
  ]) {
    const harness = createHarness({ contextValue });
    await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro' }, authorization: authorization() }), 'assistant_invalid_context');
    assert.equal(harness.calls.provider, 0);
  }
});

test('recusa evidência que não veio do contexto', async () => {
  const harness = createHarness({ providerResponse: response({ observations: [{ statement: 'Dado inventado.', evidenceIds: ['unknown_fact'] }] }) });
  await rejectsCode(harness.service.ask({ clientRequest: { message: 'Resumo financeiro' }, authorization: authorization() }), 'assistant_provider_response_invalid');
});

test('proposta exige confirmação explícita e não é executada pelo serviço', async () => {
  const harness = createHarness({ providerResponse: response({ proposedActions: [{ proposalId: 'proposal_123456789', kind: 'draftCreate', target: 'payable_1', preview: 'Criar compromisso após revisão.', previewDigest: 'digest_1234567890', requiresExplicitConfirmation: true }] }) });
  const result = await harness.service.ask({ clientRequest: { message: 'Prepare uma conta a pagar' }, authorization: authorization() });
  assert.equal(result.proposedActions[0].requiresExplicitConfirmation, true);
  assert.equal(harness.calls.provider, 1);
});

test('fontes futuras ausentes permanecem explícitas e não são simuladas', async () => {
  const harness = createHarness();
  await harness.service.ask({ clientRequest: { message: 'Tenho orçamento suficiente?' }, authorization: authorization() });
  assert.deepEqual(harness.calls.request.missingSources, ['budgets', 'projectedBalance']);
});
