/**
 * Responsabilidade: aceita somente respostas informativas fundamentadas em
 * aliases, fontes e períodos confirmados do contexto efêmero.
 */
import { deny } from './errors.mjs';
import { assertConfirmedContext } from './policy.mjs';
import { validateCivilPeriod } from './sao_paulo_civil_time.mjs';

export const ASSISTANT_GROUNDED_RESPONSE_CONTRACT_VERSION = 'assist-grounded-response-v1';

export const ASSISTANT_RESPONSE_FINAL_STATUSES = Object.freeze([
  'grounded',
  'safe_unavailable',
]);

// Motivos fechados da admissão; nenhum deles contém texto do modelo, contexto
// financeiro ou detalhe bruto de exceção.
export const ASSISTANT_RESPONSE_FALLBACK_REASONS = Object.freeze([
  'provider_output_missing',
  'provider_output_too_large',
  'provider_output_invalid_json',
  'provider_reported_insufficient_evidence',
  'context_invalid',
  'response_shape_invalid',
  'response_schema_version_invalid',
  'response_status_invalid',
  'response_text_unsafe',
  'missing_data_invalid',
  'safe_unavailable_contract_invalid',
  'assertions_invalid',
  'assertions_missing',
  'assertion_shape_invalid',
  'assertion_text_unsafe',
  'evidence_shape_invalid',
  'evidence_period_invalid',
  'evidence_alias_unknown',
  'evidence_source_mismatch',
  'evidence_period_mismatch',
  'assertion_value_ungrounded',
]);
const fallbackReasons = new Set(ASSISTANT_RESPONSE_FALLBACK_REASONS);

export const ASSISTANT_SAFE_INSUFFICIENT_EVIDENCE_RESPONSE = Object.freeze({
  schemaVersion: 1,
  status: 'safe_unavailable',
  answer: 'Não há dados confirmados suficientes para responder com segurança neste momento.',
  assertions: [],
  missingData: ['confirmed_financial_evidence'],
  disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
});

const exactKeys = (value, keys) => value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const unsafeText = (value) => typeof value !== 'string'
  || value.trim().length < 2
  || value.length > 2_000
  || /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(value)
  || /(?<!\d)(?:\d[ .-]?){11,19}(?!\d)/.test(value)
  || /(?:bearer\s+|api[_ -]?key|private[_ -]?key|password|senha|token\s*[:=])/i.test(value)
  || /\b(compre|compra|venda|vender|alocar|alocação|pague|receba|cancele|edite|transfira|agende)\b/i.test(value);

const assertionNumbersAreGrounded = (statement, fact) => {
  const numbers = statement.match(/\d+(?:[.,]\d+)?/g) ?? [];
  if (numbers.length === 0) return true;
  if (typeof fact.value !== 'number') return false;
  return numbers.every((number) => String(fact.value) === number || String(fact.value) === number.replace(',', '.'));
};

const samePeriod = (left, right) => JSON.stringify(left) === JSON.stringify(right);
const safeUnavailable = (reason) => {
  if (!fallbackReasons.has(reason)) throw new TypeError('assistant_response_fallback_reason_invalid');
  return Object.freeze({
    response: structuredClone(ASSISTANT_SAFE_INSUFFICIENT_EVIDENCE_RESPONSE),
    finalStatus: 'safe_unavailable',
    reason,
  });
};

const grounded = (response) => Object.freeze({
  response: Object.freeze(structuredClone(response)),
  finalStatus: 'grounded',
});

/** Provider-neutral delivery gate. Only a validated ephemeral alias may bind an assertion to a fact. */
/**
 * Substitui conteúdo sem evidência por indisponibilidade segura antes da UI.
 */
export const admitGroundedAssistantResponse = ({ response, context, providerOutputIssue = undefined }) => {
  try {
    assertConfirmedContext(context);
  } catch {
    return safeUnavailable('context_invalid');
  }
  if (providerOutputIssue !== undefined) return safeUnavailable(providerOutputIssue);
  if (!exactKeys(response, ['schemaVersion', 'status', 'answer', 'assertions', 'missingData', 'disclaimer'])) {
    return safeUnavailable('response_shape_invalid');
  }
  if (response.schemaVersion !== 1) return safeUnavailable('response_schema_version_invalid');
  if (!['grounded', 'safe_unavailable'].includes(response.status)) {
    return safeUnavailable('response_status_invalid');
  }
  if (unsafeText(response.answer) || unsafeText(response.disclaimer)) {
    return safeUnavailable('response_text_unsafe');
  }
  if (!Array.isArray(response.missingData)
      || response.missingData.some((item) => typeof item !== 'string' || !/^[a-z][a-z0-9_]{2,63}$/.test(item))) {
    return safeUnavailable('missing_data_invalid');
  }
  if (!Array.isArray(response.assertions)) return safeUnavailable('assertions_invalid');
  if (response.status === 'safe_unavailable') {
    return response.assertions.length === 0 && response.missingData.length > 0
      ? safeUnavailable('provider_reported_insufficient_evidence')
      : safeUnavailable('safe_unavailable_contract_invalid');
  }
  if (response.assertions.length === 0) return safeUnavailable('assertions_missing');

  try {
    const facts = new Map(context.facts.map((fact) => [fact.evidenceId, fact]));
    for (const assertion of response.assertions) {
      if (!exactKeys(assertion, ['statement', 'evidence'])) {
        return safeUnavailable('assertion_shape_invalid');
      }
      if (unsafeText(assertion.statement)) return safeUnavailable('assertion_text_unsafe');
      if (!exactKeys(assertion.evidence, ['alias', 'source', 'period'])
          || typeof assertion.evidence.alias !== 'string') {
        return safeUnavailable('evidence_shape_invalid');
      }
      try {
        validateCivilPeriod(assertion.evidence.period);
      } catch {
        return safeUnavailable('evidence_period_invalid');
      }
      const fact = facts.get(assertion.evidence.alias);
      if (!fact) return safeUnavailable('evidence_alias_unknown');
      if (assertion.evidence.source !== fact.source) {
        return safeUnavailable('evidence_source_mismatch');
      }
      if (!samePeriod(assertion.evidence.period, fact.civilPeriod)) {
        return safeUnavailable('evidence_period_mismatch');
      }
      if (!assertionNumbersAreGrounded(assertion.statement, fact)) {
        return safeUnavailable('assertion_value_ungrounded');
      }
    }
    return grounded(response);
  } catch {
    return safeUnavailable('response_shape_invalid');
  }
};

export const assertGroundedAssistantResponse = (input) => {
  const admission = admitGroundedAssistantResponse(input);
  if (admission.finalStatus !== 'grounded') throw deny('assistant_insufficient_evidence');
  return admission.response;
};
