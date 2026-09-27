/**
 * Responsabilidade: compõe o ledger de custo da callable com ADC e banco
 * nomeado, sem conceder acesso ao banco financeiro padrão.
 */
import { AssistantCostControlLedger } from '../shared/index.mjs';
import { NamedDatabaseAssistantCostLedgerStore } from './named_database_ledger_store.mjs';
import { readAssistantRuntimeLimits } from './function_options.mjs';
import { resolveAssistantRuntimeLimits } from './runtime_limits.mjs';

/**
 * Responsabilidade: cria a porta transacional que só será acionada depois dos
 * controles de runtime, autorização e privacidade aprovarem a requisição.
 */
export const createAssistantRuntimeLedger = ({
  clock = () => new Date(),
  runtimeDiagnostics = undefined,
  runtimeLimitsReader = readAssistantRuntimeLimits,
  store = undefined,
} = {}) => {
  const resolvedStore = store ?? new NamedDatabaseAssistantCostLedgerStore({ runtimeDiagnostics });
  const currentLedger = () => {
    const { costControlLimits, ownerUsageLimits } = resolveAssistantRuntimeLimits({ runtimeLimitsReader });
    return new AssistantCostControlLedger({
      clock,
      limits: costControlLimits,
      store: resolvedStore,
      usageLimits: ownerUsageLimits,
    });
  };
  return Object.freeze({
    readUsage: (input) => currentLedger().readUsage(input),
    reserve: (input) => currentLedger().reserve(input),
    confirm: (input) => currentLedger().confirm(input),
  });
};
