/**
 * Responsabilidade: emitir somente o estágio e resultado enumerados da
 * callable. Não aceita nem serializa requisição, erro, identidade ou contexto.
 */
import { ASSISTANT_READER_FAILURE_REASONS } from '../shared/index.mjs';

const stages = new Set([
  'handler_entry',
  'auth_app_check',
  'runtime_controls',
  'authorization_consent',
  'owner_scoped_context_and_usage',
  'owner_scoped_context',
  'usage_reader',
  'activation_plan',
  'ledger_reserve',
  'vertex_model',
  'ledger_confirm',
  'response_validation',
]);
const outcomes = new Set(['started', 'passed', 'blocked', 'failed']);
const reasons = new Set(ASSISTANT_READER_FAILURE_REASONS);
const readerStages = new Set(['owner_scoped_context', 'usage_reader']);
const exactEvent = (event) => {
  if (event === null || typeof event !== 'object' || Array.isArray(event)) return false;
  const keys = Object.keys(event).sort().join('|');
  if (keys === 'outcome|stage') return true;
  return keys === 'outcome|reason|stage'
    && event.outcome === 'failed'
    && readerStages.has(event.stage)
    && reasons.has(event.reason);
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
