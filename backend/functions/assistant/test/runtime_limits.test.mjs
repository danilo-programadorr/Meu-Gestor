/**
 * Intenção: provar que somente parâmetros server-side ampliam development e
 * que roteador e ledger recebem a mesma política validada.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  InMemoryAssistantCostLedgerStore,
  createAssistantOwnerScope,
} from '../shared/index.mjs';
import { readAssistantRuntimeLimits } from '../src/function_options.mjs';
import { createAssistantRuntimeLedger } from '../src/runtime_ledger.mjs';
import {
  createAssistantRuntimeModelRouter,
  resolveAssistantRuntimeLimits,
} from '../src/runtime_limits.mjs';

const developmentLimits = () => Object.freeze({
  dailyLimitCents: 3_200,
  monthlyOperationalLimitCents: 32_000,
  costUnitsPerWindow: 256,
  proCallsPerWindow: 32,
});

test('ausência de parâmetros preserva os limites conservadores', () => {
  assert.deepEqual(readAssistantRuntimeLimits(), {
    dailyLimitCents: 500,
    monthlyOperationalLimitCents: 4_500,
    costUnitsPerWindow: 32,
    proCallsPerWindow: 4,
  });
});

test('limites development permanecem coerentes entre custo, uso e roteamento', () => {
  const resolved = resolveAssistantRuntimeLimits({ runtimeLimitsReader: developmentLimits });
  assert.deepEqual(resolved.costControlLimits, {
    dailyLimitCents: 3_200,
    monthlyOperationalLimitCents: 32_000,
  });
  assert.deepEqual(resolved.ownerUsageLimits, {
    costUnitsPerWindow: 256,
    proCallsPerWindow: 32,
    flashCostUnits: 1,
    proCostUnits: 8,
  });
  assert.equal(resolved.routerLimits.costUnitsPerWindow, 256);
  assert.equal(resolved.routerLimits.proCallsPerWindow, 32);
});

test('roteador development admite Pro após o antigo teto sem abrir escolha ao cliente', () => {
  const router = createAssistantRuntimeModelRouter({ runtimeLimitsReader: developmentLimits });
  const result = router.route({
    message: 'Compare cenários confirmados.',
    context: { facts: [], missingSources: [] },
    usage: { costUnitsInWindow: 32, proCallsInWindow: 4 },
  });
  assert.equal(result.tier, 'pro');
  assert.equal(result.costUnits, 8);
});

test('ledger development reserva Pro após o antigo teto com a mesma política', async () => {
  const ownerScope = createAssistantOwnerScope('synthetic-owner');
  const store = new InMemoryAssistantCostLedgerStore({
    daily: {}, monthly: {}, periods: {}, records: {},
    usage: { [ownerScope]: { windowDay: '2026-09-27', costUnitsInWindow: 32, proCallsInWindow: 4 } },
  });
  const ledger = createAssistantRuntimeLedger({
    clock: () => new Date('2026-09-27T15:00:00.000Z'),
    runtimeLimitsReader: developmentLimits,
    store,
  });
  await ledger.reserve({
    maximumCostCents: 100,
    ownerScope,
    requestId: '123e4567-e89b-42d3-a456-426614174016',
    tier: 'pro',
    usageCostUnits: 8,
  });
  assert.deepEqual(store.snapshot().usage[ownerScope], {
    windowDay: '2026-09-27', costUnitsInWindow: 40, proCallsInWindow: 5,
  });
});

test('configuração inválida falha fechada antes do roteamento', () => {
  assert.throws(
    () => resolveAssistantRuntimeLimits({
      runtimeLimitsReader: () => ({ ...developmentLimits(), proCallsPerWindow: 0 }),
    }),
    /assistant_runtime_limits_invalid/u,
  );
});
