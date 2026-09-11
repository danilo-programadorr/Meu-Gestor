/**
 * Intenção: prova que o aceite remoto é lido pelo bearer do próprio usuário e
 * que ausência ou forma inválida mantêm a privacidade financeira ativa.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import { createAssistantRuntimeAdapters } from '../src/runtime_adapters.mjs';

const projectId = 'demo-assistant-controls';
const uid = 'synthetic-owner';
const authority = Object.freeze({
  uid,
  authorizationHeader: 'Bearer synthetic.owner.authorization.token.for.tests',
});
const string = (value) => ({ stringValue: value });
const boolean = (value) => ({ booleanValue: value });
const timestamp = (value) => ({ timestampValue: value });

const profile = Object.freeze({
  ownerId: string(uid),
  emailVerifiedSnapshot: boolean(true),
  termsVersionAccepted: string('terms-dev-1.0.0'),
  privacyVersionAccepted: string('privacy-dev-1.0.0'),
  aiConsentEnabled: boolean(true),
  aiConsentUpdatedAt: timestamp('2026-09-07T12:00:00.000Z'),
});
const allowedSettings = Object.freeze({
  consentVersion: string('assist-context-v1'),
  financialContextAllowed: boolean(true),
  updatedAt: timestamp('2026-09-07T12:01:00.000Z'),
});

const createAdapters = ({ settings = allowedSettings } = {}) => {
  const calls = [];
  const adapters = createAssistantRuntimeAdapters({
    authFactory: () => ({ getProjectId: async () => projectId }),
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      const fields = url.includes('/assistantSettings/remote?') ? settings : profile;
      return fields === null
        ? { ok: false, json: async () => ({}) }
        : { ok: true, json: async () => ({ fields }) };
    },
  });
  return { adapters, calls };
};

test('aceite remoto canônico válido libera somente a autorização do proprietário', async () => {
  const { adapters, calls } = createAdapters();
  const authorization = await adapters.authorizationReader({ uid, ownerAuthority: authority });

  assert.equal(authorization.financialPrivacyActive, false);
  assert.equal(authorization.aiConsentEnabled, true);
  assert.equal(authorization.acceptedPolicyVersion, 'assist-context-v1');
  assert.equal(calls.length, 2);
  for (const call of calls) {
    assert.equal(call.options.method, 'GET');
    assert.equal(call.options.headers.Authorization, authority.authorizationHeader);
    assert.match(call.url, new RegExp(`/users/${uid}(?:/|\\?)`));
    assert.match(call.url, /mask\.fieldPaths=/u);
    assert.doesNotMatch(
      call.url,
      /vertex|secretmanager|metadata|transactions|accounts|payables|receivables/u,
    );
  }
});

test('ausência, revogação ou formato inválido preservam privacidade financeira ativa', async () => {
  const revoked = {
    ...allowedSettings,
    financialContextAllowed: boolean(false),
  };
  const malformed = {
    consentVersion: string('assist-context-v1'),
    financialContextAllowed: boolean(true),
  };
  for (const settings of [null, revoked, malformed]) {
    const { adapters } = createAdapters({ settings });
    const authorization = await adapters.authorizationReader({ uid, ownerAuthority: authority });
    assert.equal(authorization.financialPrivacyActive, true);
    assert.equal(authorization.aiConsentEnabled, false);
    assert.equal(authorization.acceptedPolicyVersion, null);
  }
});
