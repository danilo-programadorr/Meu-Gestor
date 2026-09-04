import { AssistantModelRouter } from './model_router.mjs';
import { ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED, resolveAssistantModelExecution } from './dual_model_execution.mjs';
import { admitOwnFinancialContext, DEFAULT_ASSISTANT_CONTEXT_SCOPE } from './context_admission.mjs';
import { assertAuthorized, assertConfirmedContext, validateClientRequest } from './policy.mjs';

export const ASSISTANT_FLUTTER_CONTRACT_VERSION = 'assist-remote-v1';

// This is deliberately compiled as enabled: the local-only boundary must fail
// closed even if a future deployment configuration is incomplete.
export const ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE = true;

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

/**
 * Accepts only the minimal Flutter payload. Identity, consent, financial
 * context, provider choice and all usage counters are server-side inputs.
 */
export const validateFlutterAssistantRequest = (request) => {
  if (!exactKeys(request, ['contractVersion', 'message'])
      || request.contractVersion !== ASSISTANT_FLUTTER_CONTRACT_VERSION) {
    throw new TypeError('assistant_flutter_contract_invalid');
  }
  return validateClientRequest({ message: request.message });
};

/**
 * Produces a non-sensitive execution decision only. It intentionally never
 * returns the message, UID, e-mail, context facts or a provider request.
 */
export const prepareAssistantRemoteActivation = ({
  flutterRequest,
  authorization,
  context,
  usage,
  modelRouter = new AssistantModelRouter(),
  killSwitchActive = ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
}) => {
  validateFlutterAssistantRequest(flutterRequest);
  assertAuthorized(authorization);
  admitOwnFinancialContext({
    authorization,
    scope: DEFAULT_ASSISTANT_CONTEXT_SCOPE,
    civilPeriod: context?.civilPeriod,
  });
  assertConfirmedContext(context);
  const routing = modelRouter.route({
    message: flutterRequest.message,
    context,
    usage,
  });
  const execution = resolveAssistantModelExecution({ routing });
  const disabledReason = killSwitchActive
    ? 'kill_switch_active'
    : execution.enabled
      ? null
      : 'provider_feature_disabled';

  return Object.freeze({
    contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
    tier: routing.tier,
    maxInputUnits: routing.maxInputUnits,
    maxOutputUnits: routing.maxOutputUnits,
    allowed: disabledReason === null && ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
    disabledReason,
  });
};

/** Only aggregate, non-user observability may cross the future runtime edge. */
export const assertSanitizedAssistantOperationalMetric = (metric) => {
  const fields = ['durationMs', 'result', 'tier'];
  if (!exactKeys(metric, fields)
      || !Number.isSafeInteger(metric.durationMs)
      || metric.durationMs < 0
      || !['blocked', 'completed', 'failed'].includes(metric.result)
      || !['flash', 'pro'].includes(metric.tier)) {
    throw new TypeError('assistant_operational_metric_invalid');
  }
  return Object.freeze({ ...metric });
};
