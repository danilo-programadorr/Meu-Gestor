import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
  AssistantContractError,
  resolveAssistantModelExecution,
} from '../src/index.mjs';

test('feature flag permanece desligada e falha com resposta segura', () => {
  assert.equal(ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED, false);
  assert.deepEqual(resolveAssistantModelExecution({ routing: { tier: 'flash' } }), {
    enabled: false, tier: 'flash', providerModel: null, fallback: 'safe_unavailable',
  });
});

test('Flash é a execução padrão quando uma borda autorizada for habilitada', () => {
  assert.deepEqual(resolveAssistantModelExecution({ routing: { tier: 'flash' }, featureEnabled: true }), {
    enabled: true, tier: 'flash', providerModel: 'gemini-2.5-flash', fallback: 'safe_unavailable',
  });
});

test('Pro só é selecionado por escalonamento já decidido pelo backend', () => {
  assert.deepEqual(resolveAssistantModelExecution({ routing: { tier: 'pro' }, featureEnabled: true }), {
    enabled: true, tier: 'pro', providerModel: 'gemini-2.5-pro', fallback: 'safe_unavailable',
  });
});

test('tier inválido falha fechado e não há seletor do usuário', () => {
  assert.throws(
    () => resolveAssistantModelExecution({ routing: { tier: 'user-selected' }, featureEnabled: true }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_execution_plan_invalid',
  );
});
