import { ASSISTANT_COST_CONTROL_LIMITS } from './cost_control_ledger.mjs';
import { ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED } from './dual_model_execution.mjs';
import { ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE } from './remote_activation_contract.mjs';

export const ASSISTANT_DEVELOPMENT_ACTIVATION_READINESS_VERSION = 'assist-development-activation-readiness-v1';
export const ASSISTANT_DEVELOPMENT_ACTIVATION_PREREQUISITES = Object.freeze([
  'runtimeIdentityValidated', 'secretManagerValidated', 'appCheckValidated', 'consentValidated', 'rollbackValidated',
]);

const exactKeys = (value, keys) => value !== null && typeof value === 'object' && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

/** Local checklist only: it intentionally cannot enable a provider or retain configuration values. */
export const assessDevelopmentAssistantActivationReadiness = ({ prerequisites }) => {
  if (!exactKeys(prerequisites, ASSISTANT_DEVELOPMENT_ACTIVATION_PREREQUISITES)
      || Object.values(prerequisites).some((value) => typeof value !== 'boolean')) {
    throw new TypeError('assistant_activation_readiness_invalid');
  }
  const pending = ASSISTANT_DEVELOPMENT_ACTIVATION_PREREQUISITES.filter((key) => !prerequisites[key]);
  return Object.freeze({
    allowed: false,
    reason: ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE ? 'kill_switch_active'
      : ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED ? 'external_authorization_required' : 'provider_feature_disabled',
    pending,
    defaultTier: 'flash',
    proEscalation: 'backend_only',
    dailyLimitCents: ASSISTANT_COST_CONTROL_LIMITS.dailyLimitCents,
    monthlyOperationalLimitCents: ASSISTANT_COST_CONTROL_LIMITS.monthlyOperationalLimitCents,
  });
};
