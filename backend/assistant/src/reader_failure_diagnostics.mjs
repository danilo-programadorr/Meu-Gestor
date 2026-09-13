/**
 * Responsabilidade: transportar somente uma classificação fechada de falha
 * dos leitores runtime, sem carregar causa, mensagem, identidade ou conteúdo.
 */
export const ASSISTANT_READER_FAILURE_REASONS = Object.freeze([
  'authorization_denied',
  'adc_authentication_unavailable',
  'document_missing',
  'schema_invalid',
  'period_invalid',
  'limit_exceeded',
  'timeout',
  'unclassified',
]);

const reasons = new Set(ASSISTANT_READER_FAILURE_REASONS);

export const isAssistantReaderFailureReason = (value) => reasons.has(value);

export class AssistantReaderFailure extends Error {
  constructor(code, diagnosticReason) {
    if (typeof code !== 'string' || !/^assistant_[a-z0-9_]+$/u.test(code)
        || !isAssistantReaderFailureReason(diagnosticReason)) {
      throw new TypeError('assistant_reader_failure_invalid');
    }
    super(code);
    this.name = 'AssistantReaderFailure';
    this.code = code;
    this.diagnosticReason = diagnosticReason;
  }
}

export const assistantReaderFailureReason = (error) =>
  isAssistantReaderFailureReason(error?.diagnosticReason)
    ? error.diagnosticReason
    : 'unclassified';
