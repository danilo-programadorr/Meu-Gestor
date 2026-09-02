import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

import {
  ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  ASSISTANT_REMOTE_FUNCTION_NAME,
  ASSISTANT_SAFE_UNAVAILABLE,
  getAssistRemoteV1Gen2Options,
  registerAssistRemoteV1Gen2,
} from '../src/index.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const serverAuthorization = () => ({
  legalProfileVerified: true,
  aiConsentEnabled: true,
  profileFromServer: true,
  profileHasPendingWrites: false,
  acceptedPolicyVersion: 'assist-context-v1',
  aiConsentUpdatedAt: '2026-09-01T00:00:00.000Z',
  financialPrivacyActive: false,
});

const validRequest = {
  auth: { uid: 'synthetic-user', token: { email_verified: true } },
  app: { appId: 'synthetic-app-check' },
  data: { contractVersion: 'assist-remote-v1', message: 'Explique de forma segura.' },
};

const createEntrypoint = (overrides = {}) => {
  const calls = { authorization: 0, context: 0, usage: 0 };
  let receivedOptions;
  const entrypoint = registerAssistRemoteV1Gen2({
    onCall: (options, handler) => { receivedOptions = options; return handler; },
    HttpsError: FakeHttpsError,
    authorizationReader: async () => { calls.authorization += 1; return serverAuthorization(); },
    contextReader: async () => {
      calls.context += 1;
      return {
        isFromServer: true, hasPendingWrites: false, ownerVerified: true,
        generatedAt: '2026-09-01T00:00:00.000Z',
        period: { start: '2026-09-01T00:00:00.000Z', end: '2026-09-01T00:00:00.000Z' },
        facts: [], missingSources: [],
      };
    },
    usageReader: async () => { calls.usage += 1; return { costUnitsInWindow: 0, proCallsInWindow: 0 }; },
    ledger: { reserve: async () => undefined, confirm: async () => undefined },
    ...overrides,
  });
  return { calls, entrypoint, receivedOptions };
};

test('registra somente assistRemoteV1 com região, Auth e App Check obrigatórios', async () => {
  const { entrypoint, receivedOptions } = createEntrypoint();
  assert.deepEqual(Object.keys(entrypoint), [ASSISTANT_REMOTE_FUNCTION_NAME]);
  assert.deepEqual(receivedOptions, ASSISTANT_REMOTE_CALLABLE_OPTIONS);
  assert.equal(receivedOptions.region, 'southamerica-east1');
  assert.equal(receivedOptions.enforceAppCheck, true);
  assert.deepEqual(getAssistRemoteV1Gen2Options(), ASSISTANT_REMOTE_CALLABLE_OPTIONS);
  assert.deepEqual(await entrypoint.assistRemoteV1(validRequest), ASSISTANT_SAFE_UNAVAILABLE);
});

test('registro preserva bloqueios de Auth e App Check antes de leitores server-side', async () => {
  const withoutAuth = createEntrypoint();
  await assert.rejects(withoutAuth.entrypoint.assistRemoteV1({ ...validRequest, auth: null }), (error) => error.code === 'unauthenticated');
  assert.deepEqual(withoutAuth.calls, { authorization: 0, context: 0, usage: 0 });

  const withoutAppCheck = createEntrypoint();
  await assert.rejects(withoutAppCheck.entrypoint.assistRemoteV1({ ...validRequest, app: null }), (error) => error.code === 'failed-precondition');
  assert.deepEqual(withoutAppCheck.calls, { authorization: 0, context: 0, usage: 0 });
});

test('registro não contém SDK, URL ou chamada estrutural de Vertex', async () => {
  const source = await readFile(new URL('../src/firebase_gen2_registration.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /vertex|aiplatform|https?:\/\//iu);
  assert.doesNotMatch(source, /secretmanager|api[_-]?key|generatecontent/iu);
});
