import assert from 'node:assert/strict';
import test from 'node:test';

import { AssistantContractError, AssistantModelRouter } from '../src/index.mjs';

const context = (facts = []) => ({ facts, missingSources: [] });
const usage = (overrides = {}) => ({ costUnitsInWindow: 0, proCallsInWindow: 0, ...overrides });

test('Flash é a rota padrão para conversa e explicação comum', () => {
  const route = new AssistantModelRouter().route({
    message: 'Explique meu resumo mensal com clareza',
    context: context(),
    usage: usage(),
  });
  assert.equal(route.tier, 'flash');
  assert.equal(route.reason, 'common_explanation');
});

test('Pro exige múltiplos sinais de análise complexa decididos no backend', () => {
  const route = new AssistantModelRouter().route({
    message: 'Compare múltiplos períodos e projete cenários com as fontes disponíveis',
    context: context(),
    usage: usage(),
  });
  assert.equal(route.tier, 'pro');
  assert.equal(route.reason, 'complex_analysis');
});

test('limites de Pro falham fechados sem rebaixar análise complexa', () => {
  assert.throws(
    () => new AssistantModelRouter().route({
      message: 'Compare múltiplos períodos e projete cenários com as fontes disponíveis',
      context: context(),
      usage: usage({ proCallsInWindow: 4 }),
    }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_pro_limit_reached',
  );
});

test('limites de custo e contexto são aplicados antes do gateway', () => {
  const router = new AssistantModelRouter();
  assert.throws(
    () => router.route({ message: 'Explique meu mês', context: context(), usage: usage({ costUnitsInWindow: 32 }) }),
    (error) => error.code === 'assistant_usage_limit_reached',
  );
  assert.throws(
    () => router.route({ message: 'Explique meu mês', context: context(Array.from({ length: 129 }, (_, index) => ({ index }))), usage: usage() }),
    (error) => error.code === 'assistant_context_limit_exceeded',
  );
});

test('cliente não consegue escolher tier pelo contrato público', async () => {
  const { validateClientRequest } = await import('../src/policy.mjs');
  assert.throws(
    () => validateClientRequest({ message: 'Resumo', model: 'pro' }),
    (error) => error.code === 'assistant_invalid_request',
  );
});
