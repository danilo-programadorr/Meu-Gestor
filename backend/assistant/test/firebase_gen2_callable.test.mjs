import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AssistantContractError,
  AssistantReaderFailure,
  ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  ASSISTANT_SAFE_UNAVAILABLE,
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
    providerGateway: { generate: async () => { calls.provider += 1; throw new Error('provider_must_not_run'); } },
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
    providerGateway: { generate: async () => undefined },
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
  assert.deepEqual(events.slice(-4), [
    { stage: 'usage_reader', outcome: 'passed' },
    { stage: 'owner_scoped_context_and_usage', outcome: 'passed' },
    { stage: 'activation_plan', outcome: 'started' },
    {
      stage: 'activation_plan', outcome: 'failed', code: 'assistant_context_limit_exceeded',
    },
  ]);
  assert.deepEqual(calls, {
    authorization: 1, context: 1, usage: 1, reserve: 0, confirm: 0, provider: 0,
  });
});

test('diagnóstico runtime separa falha de uso e aguarda sucesso do contexto antes de falhar fechado', async () => {
  const events = [];
  let releaseContext;
  const contextPending = new Promise((resolve) => { releaseContext = resolve; });
  const { calls, invoke } = build({
    killSwitchActive: false,
    providerFeatureEnabled: true,
    contextReader: async () => {
      calls.context += 1;
      await contextPending;
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
  releaseContext();
  await assert.rejects(invocation, (error) => error.code === 'failed-precondition');
  assert.deepEqual(events, [
    { stage: 'handler_entry', outcome: 'started' },
    { stage: 'auth_app_check', outcome: 'passed' },
    { stage: 'runtime_controls', outcome: 'started' },
    { stage: 'runtime_controls', outcome: 'passed' },
    { stage: 'authorization_consent', outcome: 'started' },
    { stage: 'authorization_consent', outcome: 'passed' },
    { stage: 'owner_scoped_context_and_usage', outcome: 'started' },
    { stage: 'owner_scoped_context', outcome: 'started' },
    { stage: 'usage_reader', outcome: 'started' },
    { stage: 'usage_reader', outcome: 'failed', reason: 'document_missing' },
    { stage: 'owner_scoped_context', outcome: 'passed' },
    { stage: 'owner_scoped_context_and_usage', outcome: 'failed' },
  ]);
  assert.deepEqual(calls, { authorization: 1, context: 1, usage: 1, reserve: 0, confirm: 0, provider: 0 });
  assert.doesNotMatch(JSON.stringify(events), /synthetic-user|synthetic\.callable|Explique|stack|message/iu);
});

test('diagnóstico runtime separa falha de contexto sem permitir uso concluído avançar ao ledger', async () => {
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
  assert.deepEqual(calls, { authorization: 1, context: 1, usage: 1, reserve: 0, confirm: 0, provider: 0 });
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
  assert.ok(events.some((event) => event.stage === 'usage_reader'
    && event.outcome === 'failed' && event.reason === 'unclassified'));
});

test('diagnóstico runtime é best-effort e não flexibiliza a callable', async () => {
  const { calls, invoke } = build({
    runtimeDiagnostics: { report: () => { throw new Error('diagnostics_unavailable'); } },
  });
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0, provider: 0 });
});
