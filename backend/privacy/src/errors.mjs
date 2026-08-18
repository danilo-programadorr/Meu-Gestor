export class PrivacyBackendFailure extends Error {
  constructor(code) {
    super(code);
    this.code = code;
    this.name = 'PrivacyBackendFailure';
  }
}

export const deny = (code) => new PrivacyBackendFailure(code);
