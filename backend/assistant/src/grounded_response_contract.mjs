import { deny } from './errors.mjs';
import { assertConfirmedContext } from './policy.mjs';
import { validateCivilPeriod } from './sao_paulo_civil_time.mjs';

export const ASSISTANT_GROUNDED_RESPONSE_CONTRACT_VERSION = 'assist-grounded-response-v1';

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
const safeUnavailable = () => structuredClone(ASSISTANT_SAFE_INSUFFICIENT_EVIDENCE_RESPONSE);

/** Provider-neutral delivery gate. Only a validated ephemeral alias may bind an assertion to a fact. */
export const admitGroundedAssistantResponse = ({ response, context }) => {
  try {
    assertConfirmedContext(context);
    if (!exactKeys(response, ['schemaVersion', 'status', 'answer', 'assertions', 'missingData', 'disclaimer'])
        || response.schemaVersion !== 1 || response.status !== 'grounded'
        || unsafeText(response.answer) || unsafeText(response.disclaimer)
        || !Array.isArray(response.assertions) || response.assertions.length === 0
        || !Array.isArray(response.missingData)
        || response.missingData.some((item) => typeof item !== 'string' || !/^[a-z][a-z0-9_]{2,63}$/.test(item))) return safeUnavailable();
    const facts = new Map(context.facts.map((fact) => [fact.evidenceId, fact]));
    for (const assertion of response.assertions) {
      if (!exactKeys(assertion, ['statement', 'evidence']) || unsafeText(assertion.statement)
          || !exactKeys(assertion.evidence, ['alias', 'source', 'period'])
          || typeof assertion.evidence.alias !== 'string') return safeUnavailable();
      validateCivilPeriod(assertion.evidence.period);
      const fact = facts.get(assertion.evidence.alias);
      if (!fact || assertion.evidence.source !== fact.source
          || !samePeriod(assertion.evidence.period, fact.civilPeriod)
          || !assertionNumbersAreGrounded(assertion.statement, fact)) return safeUnavailable();
    }
    return Object.freeze(structuredClone(response));
  } catch {
    return safeUnavailable();
  }
};

export const assertGroundedAssistantResponse = (input) => {
  const response = admitGroundedAssistantResponse(input);
  if (response.status !== 'grounded') throw deny('assistant_insufficient_evidence');
  return response;
};
