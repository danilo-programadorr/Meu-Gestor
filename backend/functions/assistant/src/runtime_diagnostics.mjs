/**
 * Responsabilidade: emitir somente o estágio e resultado enumerados da
 * callable. Não aceita nem serializa requisição, erro, identidade ou contexto.
 */
const stages = new Set([
  'handler_entry',
  'auth_app_check',
  'runtime_controls',
  'authorization_consent',
  'owner_scoped_context_and_usage',
  'activation_plan',
  'ledger_reserve',
  'vertex_model',
  'ledger_confirm',
  'response_validation',
]);
const outcomes = new Set(['started', 'passed', 'blocked', 'failed']);
const exactEventKeys = (event) => event !== null && typeof event === 'object'
  && !Array.isArray(event) && Object.keys(event).sort().join('|') === 'outcome|stage';

export function createSanitizedAssistantRuntimeDiagnostics({ emit = console.info } = {}) {
  if (typeof emit !== 'function') throw new TypeError('assistant_runtime_diagnostics_emit_invalid');
  return Object.freeze({
    report: (event) => {
      if (!exactEventKeys(event) || !stages.has(event.stage) || !outcomes.has(event.outcome)) {
        throw new TypeError('assistant_runtime_diagnostics_event_invalid');
      }
      emit(JSON.stringify({ event: 'assistant_runtime_stage', stage: event.stage, outcome: event.outcome }));
    },
  });
}
