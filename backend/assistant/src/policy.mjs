import { deny } from './errors.mjs';

export const ASSISTANT_POLICY_VERSION = 'assist-context-v1';
export const MEMORY_MODE = 'none';

const availableSources = new Set([
  'profileConfiguration', 'accounts', 'categories', 'transactions',
  'payables', 'receivables', 'investmentPortfolios', 'investmentAssets',
  'investmentOperations', 'investmentIncome', 'delayedMarketQuotes',
  'dashboardSummary', 'investmentPerformance',
]);
const unavailableSources = new Set([
  'debtsAndInterest', 'budgets', 'goalsAndEmergencyReserve',
  'projectedBalance', 'historicalTrends',
]);
const factKinds = new Set([
  'moneyCentsBrl', 'integer', 'basisPoints', 'booleanValue', 'utcInstant',
  'safeLabel',
]);

const exactKeys = (value, keys) => {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  return actual.length === keys.length && keys.slice().sort().every((key, index) => key === actual[index]);
};

const unsafeText = (value) => {
  if (typeof value !== 'string' || value.trim().length < 2 || value.length > 2000) return true;
  return /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(value) ||
    /(?<!\d)(?:\d[ .-]?){11,19}(?!\d)/.test(value) ||
    /(?:bearer\s+|api[_ -]?key|private[_ -]?key|password|senha|token\s*[:=])/i.test(value);
};

const blockedAssistantResponse = Object.freeze({
  schemaVersion: 1,
  answer: 'Não posso fornecer essa orientação com segurança neste momento.',
  observations: [],
  missingData: [],
  proposedActions: [],
  disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
});

const unsafeAssistantOutput = (value) =>
  unsafeText(value) ||
  /\b(compre|compra|venda|vender|alocar|alocação|pague|receba|cancele|edite|transfira|agende)\b/i.test(value);

const outputNumbersAreGrounded = (value, facts) => {
  const numbers = value.match(/\d+(?:[.,]\d+)?/g) ?? [];
  const allowed = new Set(facts.filter((fact) => typeof fact.value === 'number').map((fact) => String(fact.value)));
  return numbers.every((number) => allowed.has(number.replace(',', '.')) || allowed.has(number));
};

export const validateClientRequest = (request) => {
  if (!exactKeys(request, ['message'])) throw deny('assistant_invalid_request');
  if (unsafeText(request.message)) throw deny('assistant_unsafe_content');
  return Object.freeze({ message: request.message.trim() });
};

export const assertAuthorized = (authorization) => {
  if (!authorization?.authenticated || typeof authorization.uid !== 'string' || authorization.uid.length < 1) throw deny('assistant_unauthenticated');
  if (!authorization.appCheckVerified) throw deny('assistant_app_check_required');
  if (!authorization.emailVerified) throw deny('assistant_email_not_verified');
  if (!authorization.legalProfileVerified) throw deny('assistant_legal_profile_required');
  if (authorization.requestedOwnerId !== authorization.uid) throw deny('assistant_owner_mismatch');
  if (!authorization.aiConsentEnabled) throw deny('assistant_consent_required');
  if (!authorization.profileFromServer || authorization.profileHasPendingWrites) throw deny('assistant_consent_not_confirmed');
  if (authorization.acceptedPolicyVersion !== ASSISTANT_POLICY_VERSION) throw deny('assistant_consent_version_outdated');
  if (!authorization.aiConsentUpdatedAt || Number.isNaN(Date.parse(authorization.aiConsentUpdatedAt))) throw deny('assistant_consent_not_confirmed');
};

export const assertConfirmedContext = (context) => {
  if (!context?.isFromServer || context.hasPendingWrites || context.ownerVerified !== true) throw deny('assistant_invalid_context');
  if (!Array.isArray(context.facts) || !Array.isArray(context.missingSources) || context.missingSources.some((source) => !unavailableSources.has(source))) throw deny('assistant_invalid_context');
  const ids = new Set();
  for (const fact of context.facts) {
    const integerKind = ['moneyCentsBrl', 'integer', 'basisPoints'].includes(fact.kind);
    const validValue = integerKind ? Number.isSafeInteger(fact.value) :
      fact.kind === 'booleanValue' ? typeof fact.value === 'boolean' :
        fact.kind === 'utcInstant' ? typeof fact.value === 'string' && !Number.isNaN(Date.parse(fact.value)) :
          fact.kind === 'safeLabel' ? !unsafeText(fact.value) && fact.value.length <= 80 : false;
    if (!exactKeys(fact, ['evidenceId', 'source', 'kind', 'value']) || !/^[a-z][a-z0-9_]{2,63}$/.test(fact.evidenceId) || ids.has(fact.evidenceId) || !availableSources.has(fact.source) || !factKinds.has(fact.kind) || !validValue) throw deny('assistant_invalid_context');
    ids.add(fact.evidenceId);
  }
  return ids;
};

export const validateProviderResponse = (response, evidenceIds) => {
  if (!exactKeys(response, ['schemaVersion', 'answer', 'observations', 'missingData', 'proposedActions', 'disclaimer']) || response.schemaVersion !== 1 || unsafeText(response.answer) || !Array.isArray(response.observations) || !Array.isArray(response.missingData) || !Array.isArray(response.proposedActions) || typeof response.disclaimer !== 'string') throw deny('assistant_provider_response_invalid');
  for (const observation of response.observations) {
    if (!exactKeys(observation, ['statement', 'evidenceIds']) || unsafeText(observation.statement) || !Array.isArray(observation.evidenceIds) || observation.evidenceIds.length === 0 || observation.evidenceIds.some((id) => !evidenceIds.has(id))) throw deny('assistant_provider_response_invalid');
  }
  for (const proposal of response.proposedActions) {
    if (!exactKeys(proposal, ['proposalId', 'kind', 'target', 'preview', 'previewDigest', 'requiresExplicitConfirmation']) || proposal.requiresExplicitConfirmation !== true || typeof proposal.previewDigest !== 'string' || proposal.previewDigest.length < 16) throw deny('assistant_provider_response_invalid');
  }
  return response;
};

/**
 * Single fail-closed delivery gate for every model tier. It never exposes a
 * rejected provider response, and its fallback contains no user data.
 */
export const enforceAssistantSafetyGate = ({ response, evidenceIds, facts, financialPrivacyActive = false }) => {
  try {
    const validated = validateProviderResponse(response, evidenceIds);
    const output = [validated.answer, validated.disclaimer, ...validated.observations.map((item) => item.statement)];
    if (validated.proposedActions.length > 0
        || output.some(unsafeAssistantOutput)
        || output.some((value) => !outputNumbersAreGrounded(value, facts))
        || (financialPrivacyActive && output.some((value) => /\d/.test(value)))) {
      return blockedAssistantResponse;
    }
    return validated;
  } catch {
    return blockedAssistantResponse;
  }
};
