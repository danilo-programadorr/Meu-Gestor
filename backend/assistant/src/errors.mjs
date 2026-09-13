import { isAssistantReaderFailureReason } from './reader_failure_diagnostics.mjs';

export class AssistantContractError extends Error {
  constructor(code, diagnosticReason = undefined) {
    super(code);
    this.name = 'AssistantContractError';
    this.code = code;
    if (diagnosticReason !== undefined) {
      if (!isAssistantReaderFailureReason(diagnosticReason)) {
        throw new TypeError('assistant_contract_diagnostic_reason_invalid');
      }
      this.diagnosticReason = diagnosticReason;
    }
  }
}

export const deny = (code, diagnosticReason = undefined) =>
  new AssistantContractError(code, diagnosticReason);
