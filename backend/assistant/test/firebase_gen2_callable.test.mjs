import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AssistantContractError,
  AssistantReaderFailure,
  ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  ASSISTANT_SAFE_UNAVAILABLE,
  ASSISTANT_SAFE_UNAVAILABLE_VOICE_TEXT,
  createAssistRemoteV1Callables,
} from '../src/index.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const serverAuthorization = (overrides = {}) => ({
  legalProfileVerified: true,
  aiConsentEnabled: true,
  profileFromServer: true,
  profileHasPendingWrites: false,
  acceptedPolicyVersion: 'assist-context-v1',
  aiConsentUpdatedAt: '2026-09-01T00:00:00.000Z',
  financialPrivacyActive: false,
  ...overrides,
});

const context = () => ({
  isFromServer: true,
  hasPendingWrites: false,
  ownerVerified: true,
  generatedAt: '2026-09-02T03:00:00.000Z',
  civilPeriod: {
    timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-09-02',
  },
  technicalWindow: {
    start: '2026-09-01T03:00:00.000Z', endExclusive: '2026-09-02T03:00:00.000Z',
  },
  availableDataWindow: {
    start: '2026-09-01T03:00:00.000Z', endExclusive: '2026-09-02T03:00:00.000Z',
  },
  periodComplete: true,
  facts: [{
    evidenceId: 'saldo_confirmado', source: 'dashboardSummary', kind: 'moneyCentsBrl', value: 75000,
    civilPeriod: {
      timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-09-02',
    },
    evidence: {
      alias: 'saldo_confirmado', source: 'dashboardSummary',
      period: {
        timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-09-02',
      },
    },
  }],
  missingSources: [],
});

const request = (overrides = {}) => ({
  auth: { uid: 'synthetic-user', token: { email_verified: true } },
  app: { appId: 'synthetic-app-check' },
  rawRequest: {
    headers: {
      authorization: 'Bearer synthetic.callable.owner.token.without.pii',
    },
  },
  data: { contractVersion: 'assist-remote-v1', message: 'Explique este resumo com segurança.' },
  ...overrides,
});

const build = (overrides = {}) => {
  const calls = { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 };
  const callables = createAssistRemoteV1Callables({
    onCall: (_options, handler) => handler,
    HttpsError: FakeHttpsError,
    authorizationReader: async () => { calls.authorization += 1; return serverAuthorization(); },
    contextReader: async () => { calls.context += 1; return context(); },
    usageReader: async () => { calls.usage += 1; return { costUnitsInWindow: 0, proCallsInWindow: 0 }; },
    ledger: {
      reserve: async () => { calls.reserve += 1; },
      confirm: async () => { calls.confirm += 1; },
    },
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: {
            schemaVersion: 1, status: 'ready', intent: 'financial_overview',
            clarificationCode: 'none', clarificationQuestion: '',
            periodCode: 'today', financialTool: 'overview',
          },
          durationMs: 1, confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'STOP' },
        };
      },
      generate: async () => { calls.provider += 1; throw new Error('provider_must_not_run'); },
    },
    ...overrides,
  });
  return { calls, invoke: callables.assistRemoteV1 };
};

test('callable Gen 2 fixa limites conservadores, App Check e resposta safe_unavailable sem ler dados', async () => {
  let receivedOptions;
  const { calls, invoke } = build({ onCall: (options, handler) => { receivedOptions = options; return handler; } });
  assert.deepEqual(receivedOptions, ASSISTANT_REMOTE_CALLABLE_OPTIONS);
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});

test('nega ausência de autenticação antes de qualquer leitor server-side', async () => {
  const { calls, invoke } = build();
  await assert.rejects(invoke(request({ auth: null })), (error) => error.code === 'unauthenticated');
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});

test('nega e-mail não verificado ou App Check ausente antes de qualquer leitor server-side', async () => {
  const unverifiedEmail = build();
  await assert.rejects(
    unverifiedEmail.invoke(request({ auth: { uid: 'synthetic-user', token: { email_verified: false } } })),
    (error) => error.code === 'permission-denied',
  );
  assert.equal(unverifiedEmail.calls.authorization, 0);

  const withoutAppCheck = build();
  await assert.rejects(withoutAppCheck.invoke(request({ app: null })), (error) => error.code === 'failed-precondition');
  assert.equal(withoutAppCheck.calls.authorization, 0);
});

test('estado desligado não consulta consentimento, privacidade ou contexto', async () => {
  const { calls, invoke } = build({
    authorizationReader: async () => serverAuthorization({ aiConsentEnabled: false, financialPrivacyActive: true }),
  });
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});

test('controles são lidos no runtime da callable, nunca durante sua composição', async () => {
  let reads = 0;
  const { calls, invoke } = build({
    runtimeControlsReader: () => {
      reads += 1;
      return Object.freeze({ killSwitchActive: true, providerFeatureEnabled: false });
    },
  });
  assert.equal(reads, 0);
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.equal(reads, 1);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});

test('rejeita contexto, UID, e-mail, modelo, custo e instruções do cliente', async () => {
  const forbiddenFields = ['context', 'uid', 'email', 'model', 'cost', 'instructions'];
  for (const field of forbiddenFields) {
    const { invoke } = build();
    await assert.rejects(
      invoke(request({ data: { contractVersion: 'assist-remote-v1', message: 'Resumo seguro', [field]: 'synthetic' } })),
      (error) => error.code === 'invalid-argument',
    );
  }
});

test('estado desligado não escolhe Flash ou Pro nem retorna modelo ao cliente', async () => {
  const tiers = [];
  const modelRouter = {
    route: ({ message }) => {
      const tier = message.includes('cenários') ? 'pro' : 'flash';
      tiers.push(tier);
      return { tier, maxInputUnits: 2500, maxOutputUnits: 800, costUnits: tier === 'pro' ? 8 : 1 };
    },
  };
  const { invoke } = build({ modelRouter });
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(await invoke(request({ data: { contractVersion: 'assist-remote-v1', message: 'Compare cenários sintéticos.' } })), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(tiers, []);
});

test('estado desligado não consulta custo nem reserva no ledger', async () => {
  const { calls, invoke } = build({ usageReader: async () => ({ costUnitsInWindow: 32, proCallsInWindow: 0 }) });
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.equal(calls.usage, 0);
  assert.equal(calls.reserve, 0);
  assert.equal(calls.confirm, 0);
});

test('factory exige gateway mesmo com o provedor desligado e não habilita por padrão', () => {
  const base = {
    onCall: (_options, handler) => handler,
    HttpsError: FakeHttpsError,
    authorizationReader: async () => serverAuthorization(),
    contextReader: async () => context(),
    usageReader: async () => ({ costUnitsInWindow: 0, proCallsInWindow: 0 }),
    ledger: { reserve: async () => undefined, confirm: async () => undefined },
  };
  assert.throws(() => createAssistRemoteV1Callables(base), /assistant_provider_gateway_port_invalid/);
  assert.doesNotThrow(() => createAssistRemoteV1Callables({
    ...base,
    providerGateway: { plan: async () => undefined, generate: async () => undefined },
  }));
});

test('rota futura delega somente a autoridade do envelope ao leitor próprio', async () => {
  let receivedAuthority;
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    contextReader: async ({ ownerAuthority }) => {
      calls.context += 1;
      receivedAuthority = ownerAuthority;
      return context();
    },
  });

  await assert.rejects(
    invoke(request()),
    (error) => error.code === 'failed-precondition',
  );
  assert.deepEqual(receivedAuthority, {
    uid: 'synthetic-user',
    authorizationHeader: 'Bearer synthetic.callable.owner.token.without.pii',
  });
  assert.equal(calls.context, 1);
});

test('rota futura falha fechada sem bearer do envelope autenticado', async () => {
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
  });

  await assert.rejects(
    invoke(request({ rawRequest: { headers: {} } })),
    (error) => error.code === 'unauthenticated',
  );
  assert.equal(calls.context, 0);
});

test('lista ativos owner-scoped com composição conversacional e validação integral', async () => {
  const events = [];
  const investmentContext = context();
  const period = investmentContext.civilPeriod;
  investmentContext.facts = [
    {
      evidenceId: 'ev_assets_001', source: 'investmentAssets', kind: 'integer', value: 2,
      civilPeriod: period,
      evidence: { alias: 'ev_assets_001', source: 'investmentAssets', period },
    },
    {
      evidenceId: 'ev_assets_002', source: 'investmentAssets', kind: 'safeLabel',
      value: 'PETR4 · Petrobras PN', civilPeriod: period,
      evidence: { alias: 'ev_assets_002', source: 'investmentAssets', period },
    },
    {
      evidenceId: 'ev_assets_003', source: 'investmentAssets', kind: 'safeLabel',
      value: 'HGLG11 · CSHG Logística', civilPeriod: period,
      evidence: { alias: 'ev_assets_003', source: 'investmentAssets', period },
    },
  ];
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    contextReader: async () => { calls.context += 1; return investmentContext; },
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: {
            schemaVersion: 1, status: 'ready', intent: 'investment_assets',
            clarificationCode: 'none', clarificationQuestion: '',
            periodCode: 'today', financialTool: 'investment_assets',
          },
          durationMs: 1, confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'STOP' },
        };
      },
      generate: async ({ providerRequest }) => {
        calls.provider += 1;
        assert.equal(providerRequest.intentPlan.intent, 'investment_assets');
        assert.equal(providerRequest.context, investmentContext);
        return {
          response: {
            schemaVersion: 1,
            status: 'grounded',
            intent: 'investment_assets',
            clarificationCode: 'none',
            answer: 'Você tem PETR4 · Petrobras PN por aqui. Também aparece HGLG11 · CSHG Logística. Quer que eu detalhe algum deles?',
            assertions: [
              {
                statement: 'Você tem PETR4 · Petrobras PN por aqui.',
                evidence: investmentContext.facts[1].evidence,
              },
              {
                statement: 'Também aparece HGLG11 · CSHG Logística. Quer que eu detalhe algum deles?',
                evidence: investmentContext.facts[2].evidence,
              },
            ],
            missingData: [],
          },
          durationMs: 1,
          confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'STOP' },
        };
      },
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  const response = await invoke(request({
    data: { contractVersion: 'assist-remote-v1', message: 'Quais ativos eu possuo?' },
  }));

  assert.equal(response.status, 'grounded');
  assert.match(response.answer, /PETR4 · Petrobras PN/u);
  assert.match(response.answer, /HGLG11 · CSHG Logística/u);
  assert.deepEqual(calls, {
    authorization: 1, context: 1, usage: 2, reserve: 2, confirm: 2, provider: 2,
  });
  assert.deepEqual(events.at(-1), {
    stage: 'response_validation', outcome: 'passed', finalStatus: 'grounded',
  });
});

test('intenção não resolvida pede esclarecimento sem ler contexto financeiro', async () => {
  const events = [];
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: {
            schemaVersion: 1,
            status: 'safe_unavailable',
            intent: 'unknown',
            clarificationCode: 'none',
            clarificationQuestion: '',
            periodCode: 'none',
            financialTool: 'none',
          },
          durationMs: 1,
          confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'STOP' },
        };
      },
      generate: async () => { throw new Error('generate_must_not_run'); },
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  const response = await invoke(request());
  assert.deepEqual(response, {
    status: 'clarification_required',
    contractVersion: 'assist-remote-v1',
    intent: 'unknown',
    clarificationCode: 'intent_ambiguous',
    question: 'Me conta: o que você quer ver nas suas finanças?',
  });
  assert.equal(calls.context, 0);
  assert.equal(calls.reserve, 1);
  assert.equal(calls.confirm, 1);
  assert.equal(calls.provider, 1);
  assert.deepEqual(events.at(-1), {
    stage: 'response_validation',
    outcome: 'passed',
    finalStatus: 'clarification_required',
  });
});

test('modo voz sintetiza somente após admitir o esclarecimento e contabiliza a chamada', async () => {
  const events = [];
  const audio = {
    mimeType: 'audio/wav',
    dataBase64: Buffer.concat([
      Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVE'), Buffer.alloc(512),
    ]).toString('base64'),
  };
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: {
            schemaVersion: 1,
            status: 'clarification_required',
            intent: 'financial_overview',
            clarificationCode: 'period_required',
            clarificationQuestion: 'Você quer analisar este mês ou o mês anterior?',
            periodCode: 'none',
            financialTool: 'none',
          },
          durationMs: 2,
          confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'STOP' },
        };
      },
      generate: async () => { throw new Error('generate_must_not_run'); },
      synthesize: async ({ text }) => {
        calls.provider += 1;
        assert.equal(text, 'Você quer analisar este mês ou o mês anterior?');
        return { audio, durationMs: 3, confirmedCostCents: 2 };
      },
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  const response = await invoke(request({
    data: {
      contractVersion: 'assist-remote-v1',
      message: 'Prepare um relatório.',
      responseMode: 'voice',
    },
  }));

  assert.deepEqual(response.audio, audio);
  assert.equal(calls.reserve, 2);
  assert.equal(calls.confirm, 2);
  assert.equal(calls.provider, 2);
  assert.deepEqual(events.slice(-7), [
    { stage: 'response_validation', outcome: 'passed', finalStatus: 'clarification_required' },
    { stage: 'voice_ledger_reserve', outcome: 'started' },
    { stage: 'voice_ledger_reserve', outcome: 'passed' },
    { stage: 'voice_model', outcome: 'started' },
    { stage: 'voice_model', outcome: 'passed' },
    { stage: 'voice_ledger_confirm', outcome: 'started' },
    { stage: 'voice_ledger_confirm', outcome: 'passed' },
  ]);
});

test('fallback seguro em voz usa áudio neural controlado e não lê contexto', async () => {
  const audio = {
    mimeType: 'audio/wav',
    dataBase64: Buffer.concat([
      Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVE'), Buffer.alloc(512),
    ]).toString('base64'),
  };
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: null,
          providerOutputIssue: 'provider_output_max_tokens',
          durationMs: 2,
          confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'MAX_TOKENS' },
        };
      },
      generate: async () => { throw new Error('generate_must_not_run'); },
      synthesize: async ({ text }) => {
        calls.provider += 1;
        assert.equal(text, ASSISTANT_SAFE_UNAVAILABLE_VOICE_TEXT);
        return { audio, durationMs: 3, confirmedCostCents: 2 };
      },
    },
  });

  const response = await invoke(request({
    data: {
      contractVersion: 'assist-remote-v1',
      message: 'Pergunta sintética segura.',
      responseMode: 'voice',
    },
  }));

  assert.equal(response.status, 'safe_unavailable');
  assert.deepEqual(response.audio, audio);
  assert.equal(calls.context, 0);
  assert.equal(calls.reserve, 2);
  assert.equal(calls.confirm, 2);
  assert.equal(calls.provider, 2);
});

test('fallback seguro em texto permanece mínimo e não sintetiza voz', async () => {
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    providerGateway: {
      plan: async () => {
        calls.provider += 1;
        return {
          plan: null,
          providerOutputIssue: 'provider_output_max_tokens',
          durationMs: 2,
          confirmedCostCents: 1,
          providerDiagnostics: { finishReason: 'MAX_TOKENS' },
        };
      },
      generate: async () => { throw new Error('generate_must_not_run'); },
      synthesize: async () => { throw new Error('synthesize_must_not_run'); },
    },
  });

  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.equal(calls.context, 0);
  assert.equal(calls.reserve, 1);
  assert.equal(calls.confirm, 1);
  assert.equal(calls.provider, 1);
});

test('falha do plano é atribuída ao estágio correto com código sanitizado', async () => {
  const events = [];
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    modelRouter: {
      route: () => { throw new AssistantContractError('assistant_context_limit_exceeded'); },
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  await assert.rejects(invoke(request()), (error) => error.code === 'failed-precondition');
  assert.deepEqual(events.slice(-3), [
    { stage: 'intent_usage_reader', outcome: 'passed' },
    { stage: 'intent_activation_plan', outcome: 'started' },
    {
      stage: 'intent_activation_plan', outcome: 'failed', code: 'assistant_context_limit_exceeded',
    },
  ]);
  assert.deepEqual(calls, {
    authorization: 1, context: 0, usage: 1, reserve: 0, confirm: 0, provider: 0,
  });
});

test('diagnóstico runtime falha no uso antes de planejar ou ler contexto', async () => {
  const events = [];
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    contextReader: async () => {
      calls.context += 1;
      return context();
    },
    usageReader: async () => {
      calls.usage += 1;
      throw new AssistantReaderFailure(
        'assistant_named_ledger_unavailable',
        'document_missing',
      );
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  const invocation = invoke(request());
  await Promise.resolve();
  assert.equal(calls.reserve, 0);
  await assert.rejects(invocation, (error) => error.code === 'failed-precondition');
  assert.deepEqual(events, [
    { stage: 'handler_entry', outcome: 'started' },
    { stage: 'auth_app_check', outcome: 'passed' },
    { stage: 'runtime_controls', outcome: 'started' },
    { stage: 'runtime_controls', outcome: 'passed' },
    { stage: 'authorization_consent', outcome: 'started' },
    { stage: 'authorization_consent', outcome: 'passed' },
    { stage: 'intent_usage_reader', outcome: 'started' },
    { stage: 'intent_usage_reader', outcome: 'failed', reason: 'document_missing' },
    { stage: 'intent_usage_reader', outcome: 'failed' },
  ]);
  assert.deepEqual(calls, { authorization: 1, context: 0, usage: 1, reserve: 0, confirm: 0, provider: 0 });
  assert.doesNotMatch(JSON.stringify(events), /synthetic-user|synthetic\.callable|Explique|stack|message/iu);
});

test('falha de contexto após o plano não avança à reserva da resposta', async () => {
  const events = [];
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    contextReader: async () => {
      calls.context += 1;
      throw new AssistantReaderFailure('assistant_context_unavailable', 'period_invalid');
    },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  await assert.rejects(invoke(request()), (error) => error.code === 'failed-precondition');
  assert.deepEqual(events.slice(-6), [
    { stage: 'owner_scoped_context_and_usage', outcome: 'started' },
    { stage: 'owner_scoped_context', outcome: 'started' },
    { stage: 'usage_reader', outcome: 'started' },
    { stage: 'owner_scoped_context', outcome: 'failed', reason: 'period_invalid' },
    { stage: 'usage_reader', outcome: 'passed' },
    { stage: 'owner_scoped_context_and_usage', outcome: 'failed' },
  ]);
  assert.deepEqual(calls, { authorization: 1, context: 1, usage: 2, reserve: 1, confirm: 1, provider: 1 });
});

test('diagnóstico runtime não adivinha motivo de erro sem classificação de origem', async () => {
  const events = [];
  const { invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    usageReader: async () => { throw new Error('opaque_dependency_failure'); },
    runtimeDiagnostics: { report: (event) => events.push(event) },
  });

  await assert.rejects(invoke(request()), (error) => error.code === 'failed-precondition');
  assert.ok(events.some((event) => event.stage === 'intent_usage_reader'
    && event.outcome === 'failed' && event.reason === 'unclassified'));
});

test('diagnóstico runtime é best-effort e não flexibiliza a callable', async () => {
  const { calls, invoke } = build({
    runtimeDiagnostics: { report: () => { throw new Error('diagnostics_unavailable'); } },
  });
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});
