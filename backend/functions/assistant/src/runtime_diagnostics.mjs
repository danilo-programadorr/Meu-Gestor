/**
 * Responsabilidade: emitir somente o estágio e resultado enumerados da
 * callable. Não aceita nem serializa requisição, erro, identidade ou contexto.
 */
import {
  ASSISTANT_ACTIVATION_FAILURE_CODES,
  ASSISTANT_READER_FAILURE_REASONS,
  ASSISTANT_RESPONSE_FALLBACK_REASONS,
  ASSISTANT_RESPONSE_FINAL_STATUSES,
  ASSISTANT_VERTEX_FINISH_REASONS,
} from '../shared/index.mjs';

const stages = new Set([
  'handler_entry',
  'auth_app_check',
  'runtime_controls',
  'authorization_consent',
  'owner_scoped_context_and_usage',
  'owner_scoped_context',
  'usage_reader',
  'usage_adc_credentials',
  'usage_firestore_begin_transaction',
  'usage_firestore_read',
  'usage_firestore_commit',
  'activation_plan',
  'ledger_reserve',
  'vertex_model',
  'ledger_confirm',
  'response_validation',
]);
const outcomes = new Set(['started', 'passed', 'blocked', 'failed']);
const reasons = new Set(ASSISTANT_READER_FAILURE_REASONS);
const activationFailureCodes = new Set(ASSISTANT_ACTIVATION_FAILURE_CODES);
const responseFallbackReasons = new Set(ASSISTANT_RESPONSE_FALLBACK_REASONS);
const responseFinalStatuses = new Set(ASSISTANT_RESPONSE_FINAL_STATUSES);
const vertexFinishReasons = new Set(ASSISTANT_VERTEX_FINISH_REASONS);
const readerStages = new Set(['owner_scoped_context', 'usage_reader']);
const usageDiagnosticStages = new Set([
  'usage_adc_credentials',
  'usage_firestore_begin_transaction',
  'usage_firestore_read',
  'usage_firestore_commit',
]);
const usageHttpStages = new Set([
  'usage_firestore_begin_transaction',
  'usage_firestore_read',
  'usage_firestore_commit',
]);
const validHttpStatus = (value) => Number.isInteger(value) && value >= 100 && value <= 599;
const exactEvent = (event) => {
  if (event === null || typeof event !== 'object' || Array.isArray(event)) return false;
  const keys = Object.keys(event).sort().join('|');
  const diagnosticStage = readerStages.has(event.stage) || usageDiagnosticStages.has(event.stage);
  if (keys === 'outcome|stage') {
    return event.outcome !== 'failed'
      || (!diagnosticStage && event.stage !== 'activation_plan');
  }
  if (keys === 'outcome|reason|stage') {
    return event.outcome === 'failed' && diagnosticStage && reasons.has(event.reason);
  }
  if (keys === 'code|outcome|stage') {
    return event.stage === 'activation_plan'
      && event.outcome === 'failed'
      && activationFailureCodes.has(event.code);
  }
  if (keys === 'httpStatus|outcome|stage') {
    return event.outcome === 'passed'
      && usageHttpStages.has(event.stage)
      && validHttpStatus(event.httpStatus);
  }
  if (keys === 'finalStatus|outcome|stage') {
    return event.stage === 'response_validation'
      && event.outcome === 'passed'
      && event.finalStatus === 'grounded';
  }
  if (keys === 'candidateCount|finishReason|nonTextPartCount|outcome|providerBlocked|stage|textPartCount') {
    return event.stage === 'vertex_model'
      && event.outcome === 'passed'
      && vertexFinishReasons.has(event.finishReason)
      && [event.candidateCount, event.textPartCount, event.nonTextPartCount]
        .every((value) => Number.isSafeInteger(value) && value >= 0 && value <= 100)
      && typeof event.providerBlocked === 'boolean';
  }
  if (keys === 'finalStatus|outcome|reason|stage') {
    return event.stage === 'response_validation'
      && event.outcome === 'passed'
      && event.finalStatus === 'safe_unavailable'
      && responseFinalStatuses.has(event.finalStatus)
      && responseFallbackReasons.has(event.reason);
  }
  return keys === 'httpStatus|outcome|reason|stage'
    && event.outcome === 'failed'
    && usageDiagnosticStages.has(event.stage)
    && reasons.has(event.reason)
    && validHttpStatus(event.httpStatus);
};

export function createSanitizedAssistantRuntimeDiagnostics({ emit = console.info } = {}) {
  if (typeof emit !== 'function') throw new TypeError('assistant_runtime_diagnostics_emit_invalid');
  return Object.freeze({
    report: (event) => {
      if (!exactEvent(event) || !stages.has(event.stage) || !outcomes.has(event.outcome)) {
        throw new TypeError('assistant_runtime_diagnostics_event_invalid');
      }
      emit(JSON.stringify({ event: 'assistant_runtime_stage', ...event }));
    },
  });
}
