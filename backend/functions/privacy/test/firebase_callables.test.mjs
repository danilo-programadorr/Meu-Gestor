import assert from 'node:assert/strict';
import test from 'node:test';
import { createFirebasePrivacyCallables } from '../src/firebase_callables.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

const now = new Date('2026-08-20T12:00:00.000Z');

function profile(uid = 'synthetic-user') {
  return {
    ownerId: uid, displayName: 'Synthetic', locale: 'pt-BR', currencyCode: 'BRL', timeZone: 'America/Sao_Paulo',
    emailVerifiedSnapshot: true, termsVersionAccepted: 'terms-dev-1.0.0', termsAcceptedAt: {},
    privacyVersionAccepted: 'privacy-dev-1.0.0', privacyAcceptedAt: {}, aiConsentEnabled: false,
    aiConsentUpdatedAt: {}, analyticsConsentEnabled: false, analyticsConsentUpdatedAt: {},
    createdAt: {}, updatedAt: {}, schemaVersion: 1,
  };
}

function request(data, overrides = {}) {
  return {
    auth: { uid: 'synthetic-user', token: { email_verified: true, auth_time: now.getTime() / 1000 } },
    app: { appId: 'synthetic-app' }, data, ...overrides,
  };
}

function harness() {
  const calls = [];
  const processor = {
    request: async ({ actor, type, confirmationPhrase, idempotencyKey }) => ({
      operationId: 'privacy-operation-synthetic-0001', type, state: 'prepared', revision: 1,
      createdAt: now, updatedAt: now, actor, confirmationPhrase, idempotencyKey,
    }),
    advance: async ({ operationId }) => ({ operationId, type: 'financialReset', state: 'confirmed', revision: 2, createdAt: now, updatedAt: now }),
    status: async ({ operationId }) => ({ operationId, type: 'financialReset', state: 'confirmed', revision: 2, createdAt: now, updatedAt: now }),
  };
  const callables = createFirebasePrivacyCallables({
    onCall: (options, handler) => { calls.push({ options, handler }); return handler; },
    HttpsError: FakeHttpsError, processor, profileReader: async () => profile(),
    clock: { now: () => now }, options: Object.freeze({ enforceAppCheck: true }), logger: { info: () => undefined },
  });
  return { calls, processor, callables };
}

async function rejectsCode(action, code) {
  await assert.rejects(action, (error) => error instanceof FakeHttpsError && error.code === code);
}

test('expõe somente as três callables privadas com App Check obrigatório', () => {
  const h = harness();
  assert.deepEqual(Object.keys(h.callables).sort(), ['confirmPrivacyOperation', 'getPrivacyOperationStatus', 'preparePrivacyOperation']);
  assert.equal(h.calls.length, 3);
  assert.equal(h.calls.every((call) => call.options.enforceAppCheck === true), true);
});

test('prepare deriva identidade no servidor e descarta a frase da resposta', async () => {
  const h = harness();
  const result = await h.callables.preparePrivacyOperation(request({
    type: 'financialReset', confirmationPhrase: 'RESETAR DADOS FINANCEIROS', idempotencyKey: 'synthetic-idempotency-key-0001',
  }));
  assert.deepEqual(result, {
    operationId: 'privacy-operation-synthetic-0001', type: 'financialReset', state: 'prepared', revision: 1,
    createdAt: now.toISOString(), updatedAt: now.toISOString(),
  });
});

test('nega Auth, e-mail, App Check, perfil, auth_time e campos extras antes do processador', async () => {
  const h = harness();
  const data = { type: 'financialReset', confirmationPhrase: 'RESETAR DADOS FINANCEIROS', idempotencyKey: 'synthetic-idempotency-key-0001' };
  await rejectsCode(() => h.callables.preparePrivacyOperation(request(data, { auth: null })), 'unauthenticated');
  await rejectsCode(() => h.callables.preparePrivacyOperation(request(data, { auth: { uid: 'synthetic-user', token: {} } })), 'permission-denied');
  await rejectsCode(() => h.callables.preparePrivacyOperation(request(data, { app: null })), 'failed-precondition');
  await rejectsCode(() => h.callables.preparePrivacyOperation(request({ ...data, ownerId: 'other' })), 'invalid-argument');
  await rejectsCode(() => h.callables.preparePrivacyOperation(request(data, { auth: { uid: 'synthetic-user', token: { email_verified: true, auth_time: 0 } } })), 'failed-precondition');
});

test('confirm e status aceitam somente a operação do próprio solicitante', async () => {
  const h = harness();
  const data = { operationId: 'privacy-operation-synthetic-0001' };
  assert.equal((await h.callables.confirmPrivacyOperation(request(data))).state, 'confirmed');
  assert.equal((await h.callables.getPrivacyOperationStatus(request(data))).operationId, data.operationId);
  await rejectsCode(() => h.callables.getPrivacyOperationStatus(request({ ...data, uid: 'other' })), 'invalid-argument');
});
