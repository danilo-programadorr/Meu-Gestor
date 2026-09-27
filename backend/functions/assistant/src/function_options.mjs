/**
 * Responsabilidade: centraliza limites Gen 2 e parâmetros sem valores
 * versionados, preservando o circuito fechado por padrão.
 */
import { defineBoolean, defineInt, defineString } from 'firebase-functions/params';

// O valor existe apenas no ambiente de deploy autorizado. Sem esse parâmetro,
// a CLI não pode materializar a configuração da Function.
export const assistantRuntimeServiceAccount = defineString('ASSISTANT_RUNTIME_SERVICE_ACCOUNT');
export const assistantProviderFeatureEnabled = defineBoolean('ASSISTANT_REAL_PROVIDER_ENABLED');

// Os padrões preservam a política conservadora fora de development. Somente
// um deploy explicitamente parametrizado pode ampliar os limites operacionais.
export const assistantDailyCostLimitCents = defineInt('ASSISTANT_DAILY_COST_LIMIT_CENTS', { default: 500 });
export const assistantMonthlyOperationalLimitCents = defineInt('ASSISTANT_MONTHLY_OPERATIONAL_LIMIT_CENTS', { default: 4_500 });
export const assistantUsageCostUnitsPerWindow = defineInt('ASSISTANT_USAGE_COST_UNITS_PER_WINDOW', { default: 32 });
export const assistantProCallsPerWindow = defineInt('ASSISTANT_PRO_CALLS_PER_WINDOW', { default: 4 });

// firebase-functions 7.3.2 resolve parâmetros booleanos ausentes como false.
// Logo, o único modo de desligar o circuito é declarar explicitamente a
// sinalização inversa no ambiente autorizado; a ausência mantém o bloqueio.
const assistantKillSwitchDisabled = defineBoolean('ASSISTANT_KILL_SWITCH_DISABLED');

/**
 * Responsabilidade: lê os flags somente durante uma invocação da callable;
 * a composição e o deploy nunca materializam parâmetros booleanos.
 */
export const readAssistantRuntimeControls = () => Object.freeze({
  providerFeatureEnabled: assistantProviderFeatureEnabled.value() === true,
  killSwitchActive: assistantKillSwitchDisabled.value() !== true,
});

/** Responsabilidade: lê limites somente durante operações da callable. */
export const readAssistantRuntimeLimits = () => {
  const positiveOrDefault = (value, fallback) => Number.isSafeInteger(value) && value > 0 ? value : fallback;
  return Object.freeze({
    dailyLimitCents: positiveOrDefault(assistantDailyCostLimitCents.value(), 500),
    monthlyOperationalLimitCents: positiveOrDefault(assistantMonthlyOperationalLimitCents.value(), 4_500),
    costUnitsPerWindow: positiveOrDefault(assistantUsageCostUnitsPerWindow.value(), 32),
    proCallsPerWindow: positiveOrDefault(assistantProCallsPerWindow.value(), 4),
  });
};

export const assistantKillSwitchActive = Object.freeze({
  value: () => readAssistantRuntimeControls().killSwitchActive,
});

export const ASSISTANT_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: assistantRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  enforceAppCheck: true,
});
