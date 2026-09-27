/**
 * Responsabilidade: aplica limites parametrizados no roteador e no ledger sem
 * permitir que o cliente escolha tier, quota ou orçamento operacional.
 */
import {
  ASSISTANT_COST_CONTROL_LIMITS,
  ASSISTANT_OWNER_USAGE_LIMITS,
  AssistantModelRouter,
  DEFAULT_ROUTER_LIMITS,
} from '../shared/index.mjs';
import { readAssistantRuntimeLimits } from './function_options.mjs';

const exactKeys = (value, keys) => value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

export const resolveAssistantRuntimeLimits = ({
  runtimeLimitsReader = readAssistantRuntimeLimits,
} = {}) => {
  if (typeof runtimeLimitsReader !== 'function') throw new TypeError('assistant_runtime_limits_reader_invalid');
  const configured = runtimeLimitsReader();
  const keys = ['dailyLimitCents', 'monthlyOperationalLimitCents', 'costUnitsPerWindow', 'proCallsPerWindow'];
  if (!exactKeys(configured, keys)
      || !Object.values(configured).every((value) => Number.isSafeInteger(value) && value > 0)) {
    throw new TypeError('assistant_runtime_limits_invalid');
  }
  const costControlLimits = Object.freeze({
    ...ASSISTANT_COST_CONTROL_LIMITS,
    dailyLimitCents: configured.dailyLimitCents,
    monthlyOperationalLimitCents: configured.monthlyOperationalLimitCents,
  });
  const ownerUsageLimits = Object.freeze({
    ...ASSISTANT_OWNER_USAGE_LIMITS,
    costUnitsPerWindow: configured.costUnitsPerWindow,
    proCallsPerWindow: configured.proCallsPerWindow,
  });
  return Object.freeze({
    costControlLimits,
    ownerUsageLimits,
    routerLimits: Object.freeze({
      ...DEFAULT_ROUTER_LIMITS,
      costUnitsPerWindow: ownerUsageLimits.costUnitsPerWindow,
      proCallsPerWindow: ownerUsageLimits.proCallsPerWindow,
    }),
  });
};

/** Responsabilidade: relê a política a cada decisão de roteamento. */
export const createAssistantRuntimeModelRouter = ({
  runtimeLimitsReader = readAssistantRuntimeLimits,
} = {}) => Object.freeze({
  route(input) {
    const { routerLimits } = resolveAssistantRuntimeLimits({ runtimeLimitsReader });
    return new AssistantModelRouter({ limits: routerLimits }).route(input);
  },
});
