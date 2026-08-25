export class AssistantContractError extends Error {
  constructor(code) {
    super(code);
    this.name = 'AssistantContractError';
    this.code = code;
  }
}

export const deny = (code) => new AssistantContractError(code);
