import assert from 'node:assert/strict';
import test from 'node:test';

import {
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
  generatedAt: '2026-09-01T00:00:00.000Z',
  period: { start: '2026-09-01T00:00:00.000Z', end: '2026-09-01T00:00:00.000Z' },
  facts: [],
  missingSources: [],
});

const request = (overrides = {}) => ({
  auth: { uid: 'synthetic-user', token: { email_verified: true } },
  app: { appId: 'synthetic-app-check' },
  data: { contractVersion: 'assist-remote-v1', message: 'Explique este resumo com segurança.' },
  ...overrides,
});

const build = (overrides = {}) => {
  const calls = { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0 };
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
    ...overrides,
  });
  return { calls, invoke: callables.assistRemoteV1 };
};

test('callable Gen 2 fixa limites conservadores, App Check e resposta safe_unavailable sem ler dados', async () => {
  let receivedOptions;
  const { calls, invoke } = build({ onCall: (options, handler) => { receivedOptions = options; return handler; } });
  assert.deepEqual(receivedOptions, ASSISTANT_REMOTE_CALLABLE_OPTIONS);
  assert.deepEqual(await invoke(request()), ASSISTANT_SAFE_UNAVAILABLE);
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0 });
});

test('nega ausência de autenticação antes de qualquer leitor server-side', async () => {
  const { calls, invoke } = build();
  await assert.rejects(invoke(request({ auth: null })), (error) => error.code === 'unauthenticated');
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0 });
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
  assert.deepEqual(calls, { authorization: 0, context: 0, usage: 0, reserve: 0, confirm: 0 });
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

test('factory recusa qualquer tentativa local de desligar kill switch ou habilitar provedor', () => {
  const base = {
    onCall: (_options, handler) => handler,
    HttpsError: FakeHttpsError,
    authorizationReader: async () => serverAuthorization(),
    contextReader: async () => context(),
    usageReader: async () => ({ costUnitsInWindow: 0, proCallsInWindow: 0 }),
    ledger: { reserve: async () => undefined, confirm: async () => undefined },
  };
  assert.throws(() => createAssistRemoteV1Callables({ ...base, killSwitchActive: false }), /assistant_callable_must_start_fail_closed/);
  assert.throws(() => createAssistRemoteV1Callables({ ...base, providerFeatureEnabled: true }), /assistant_callable_must_start_fail_closed/);
});
