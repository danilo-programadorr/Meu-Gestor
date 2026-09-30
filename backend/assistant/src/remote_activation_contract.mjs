/**
 * Responsabilidade: fecha o contrato remoto mínimo e decide se a ativação
 * pode prosseguir sem transportar identidade ou contexto pelo Flutter.
 */
import { AssistantModelRouter } from './model_router.mjs';
import { ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED, resolveAssistantModelExecution } from './dual_model_execution.mjs';
import { admitOwnFinancialContext, DEFAULT_ASSISTANT_CONTEXT_SCOPE } from './context_admission.mjs';
import { AssistantContractError } from './errors.mjs';
import { assertAuthorized, assertConfirmedContext, validateClientRequest } from './policy.mjs';

export const ASSISTANT_FLUTTER_CONTRACT_VERSION = 'assist-remote-v1';

// This is deliberately compiled as enabled: the local-only boundary must fail
// closed even if a future deployment configuration is incomplete.
export const ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE = true;

// Códigos fechados da preparação; nenhum texto livre da exceção atravessa o
// diagnóstico sanitizado da Function.
export const ASSISTANT_ACTIVATION_FAILURE_CODES = Object.freeze([
  'assistant_activation_control_invalid',
  'assistant_app_check_required',
  'assistant_consent_not_confirmed',
  'assistant_consent_required',
  'assistant_consent_version_outdated',
  'assistant_context_admission_denied',
  'assistant_context_limit_exceeded',
  'assistant_email_not_verified',
  'assistant_execution_plan_invalid',
  'assistant_financial_privacy_active',
  'assistant_flutter_contract_invalid',
  'assistant_invalid_context',
  'assistant_invalid_request',
  'assistant_invalid_usage',
  'assistant_legal_profile_required',
  'assistant_owner_mismatch',
  'assistant_pro_limit_reached',
  'assistant_unauthenticated',
  'assistant_unsafe_content',
  'assistant_usage_limit_reached',
  'assistant_activation_unclassified',
]);
const activationFailureCodes = new Set(ASSISTANT_ACTIVATION_FAILURE_CODES);

export const sanitizedAssistantActivationFailureCode = (error) => {
  const candidate = error instanceof AssistantContractError
    ? error.code
    : error instanceof TypeError
      ? error.message
      : null;
  return activationFailureCodes.has(candidate) ? candidate : 'assistant_activation_unclassified';
};

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

export const ASSISTANT_CONVERSATION_INTENTS = Object.freeze([
  'unknown',
  'financial_overview',
  'balance',
  'income',
  'expenses',
  'commitments',
  'investments',
  'comparison',
  'cash_flow',
  'explanation',
]);

export const ASSISTANT_CLARIFICATION_CODES = Object.freeze([
  'intent_ambiguous',
  'period_required',
  'scope_required',
  'comparison_basis_required',
]);

export const ASSISTANT_PERIOD_CODES = Object.freeze([
  'today',
  'current_month',
  'previous_month',
]);

export const ASSISTANT_FINANCIAL_TOOLS = Object.freeze([
  'overview',
  'balance',
  'income',
  'expenses',
  'commitments',
  'investments',
  'comparison',
  'cash_flow',
]);

// Cada ferramenta libera somente grupos de leitores já owner-scoped. Nenhum
// identificador, caminho ou valor pode ser escolhido pelo modelo.
export const ASSISTANT_FINANCIAL_TOOL_SOURCES = Object.freeze({
  overview: DEFAULT_ASSISTANT_CONTEXT_SCOPE.sources,
  balance: Object.freeze(['accounts']),
  income: Object.freeze(['transactions', 'payables', 'receivables', 'investmentIncome']),
  expenses: Object.freeze(['transactions', 'payables', 'receivables']),
  commitments: Object.freeze(['payables', 'receivables', 'financialCalendar']),
  investments: Object.freeze([
    'investmentPortfolios', 'investmentAssets', 'investmentOperations', 'investmentIncome',
  ]),
  comparison: DEFAULT_ASSISTANT_CONTEXT_SCOPE.sources,
  cash_flow: Object.freeze(['transactions', 'payables', 'receivables']),
});

const conversationIntents = new Set(ASSISTANT_CONVERSATION_INTENTS);
const clarificationCodes = new Set(ASSISTANT_CLARIFICATION_CODES);

// O histórico remoto contém no máximo o turno que originou a pergunta de
// esclarecimento. Ele é não autoritativo e nunca substitui contexto do servidor.
const validateConversationContinuation = (value) => {
  if (!exactKeys(value, ['intent', 'clarificationCode', 'previousMessage'])
      || !conversationIntents.has(value.intent)
      || !clarificationCodes.has(value.clarificationCode)) {
    throw new TypeError('assistant_flutter_contract_invalid');
  }
  const validated = validateClientRequest({ message: value.previousMessage });
  return Object.freeze({
    intent: value.intent,
    clarificationCode: value.clarificationCode,
    previousMessage: validated.message,
  });
};

/**
 * Accepts only the minimal Flutter payload. Identity, consent, financial
 * context, provider choice and all usage counters are server-side inputs.
 */
export const validateFlutterAssistantRequest = (request) => {
  const hasContinuation = Object.hasOwn(request ?? {}, 'continuation');
  const hasResponseMode = Object.hasOwn(request ?? {}, 'responseMode');
  const expectedKeys = ['contractVersion', 'message'];
  if (hasContinuation) expectedKeys.push('continuation');
  if (hasResponseMode) expectedKeys.push('responseMode');
  if (!exactKeys(request, expectedKeys)
      || request.contractVersion !== ASSISTANT_FLUTTER_CONTRACT_VERSION) {
    throw new TypeError('assistant_flutter_contract_invalid');
  }
  if (hasResponseMode && !['text', 'voice'].includes(request.responseMode)) {
    throw new TypeError('assistant_flutter_contract_invalid');
  }
  const validated = validateClientRequest({ message: request.message });
  return Object.freeze({
    ...validated,
    responseMode: hasResponseMode ? request.responseMode : 'text',
    ...(hasContinuation
      ? { continuation: validateConversationContinuation(request.continuation) }
      : {}),
  });
};

/**
 * Produces a non-sensitive execution decision only. It intentionally never
 * returns the message, UID, e-mail, context facts or a provider request.
 */
/**
 * Consolida autorização, contexto confirmado, roteamento e controles em um
 * plano sem conteúdo sensível para a borda server-side.
 */
export const prepareAssistantRemoteActivation = ({
  flutterRequest,
  authorization,
  context,
  usage,
  modelRouter = new AssistantModelRouter(),
  killSwitchActive = ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  providerFeatureEnabled = ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
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
  if (typeof killSwitchActive !== 'boolean' || typeof providerFeatureEnabled !== 'boolean') {
    throw new TypeError('assistant_activation_control_invalid');
  }
  const execution = resolveAssistantModelExecution({ routing, featureEnabled: providerFeatureEnabled });
  const disabledReason = killSwitchActive
    ? 'kill_switch_active'
    : execution.enabled
      ? null
      : 'provider_feature_disabled';

  return Object.freeze({
    contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
    tier: routing.tier,
    costUnits: routing.costUnits,
    maxInputUnits: routing.maxInputUnits,
    maxOutputUnits: routing.maxOutputUnits,
    allowed: disabledReason === null && providerFeatureEnabled,
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
