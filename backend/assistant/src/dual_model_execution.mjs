/**
 * Responsabilidade: converte a escolha interna de tier em plano de execução,
 * mantendo Flash como padrão lógico e Pro restrito ao backend.
 */
import { AssistantContractError } from './errors.mjs';

export const ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED = false;

export const MODEL_EXECUTION = Object.freeze({
  flash: Object.freeze({ providerModel: 'gemini-2.5-flash', fallback: 'safe_unavailable' }),
  pro: Object.freeze({ providerModel: 'gemini-2.5-pro', fallback: 'safe_unavailable' }),
});

/**
 * Converts an already server-decided logical tier into a provider execution
 * plan. This stays disabled until a separately authorized backend exists.
 */
/**
 * Falha fechada quando a feature não foi autorizada ou o tier não é interno.
 */
export const resolveAssistantModelExecution = ({ routing, featureEnabled = ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED }) => {
  if (!routing || !['flash', 'pro'].includes(routing.tier)) {
    throw new AssistantContractError('assistant_execution_plan_invalid');
  }
  if (!featureEnabled) {
    return Object.freeze({ enabled: false, tier: routing.tier, providerModel: null, fallback: 'safe_unavailable' });
  }
  const execution = MODEL_EXECUTION[routing.tier];
  return Object.freeze({ enabled: true, tier: routing.tier, ...execution });
};
