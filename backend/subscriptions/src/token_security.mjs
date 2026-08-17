import { createHmac, randomUUID } from 'node:crypto';
import { deny, requireText } from './errors.mjs';

export class PurchaseTokenFingerprinter {
  constructor({ key, keyVersion = 'test-v1' }) {
    this.key = requireText(key, 'invalid_fingerprint_key', 512);
    this.keyVersion = requireText(keyVersion, 'invalid_fingerprint_key_version', 32);
  }

  fingerprint(token) {
    requireText(token, 'invalid_purchase_token', 4096);
    return `${this.keyVersion}:${createHmac('sha256', this.key).update(token).digest('hex')}`;
  }
}

export function createObfuscatedExternalAccountId({ uid, key, keyVersion = 'account-v1' }) {
  requireText(uid, 'invalid_obfuscated_account_uid', 256);
  requireText(key, 'invalid_obfuscated_account_key', 512);
  requireText(keyVersion, 'invalid_obfuscated_account_key_version', 32);
  return `${keyVersion}:${createHmac('sha256', key).update(uid).digest('hex')}`;
}

export class PurchaseTokenVault {
  // Cada chamada deve retornar uma referência opaca e exclusiva, mesmo para o
  // mesmo fingerprint. Isso permite descartar somente a tentativa que falhou
  // enquanto outra tentativa ainda pode estar entre store e commit.
  async store(_fingerprint, _token) {
    throw new Error('PurchaseTokenVault.store must be implemented');
  }

  async retrieve(_reference) {
    throw new Error('PurchaseTokenVault.retrieve must be implemented');
  }

  async discard(_reference) {
    throw new Error('PurchaseTokenVault.discard must be implemented');
  }
}

export class InMemoryPurchaseTokenVault extends PurchaseTokenVault {
  #entries = new Map();
  #fingerprintedTokens = new Map();
  discardFailuresRemaining = 0;

  constructor() {
    super();
  }

  async store(fingerprint, token) {
    const trustedFingerprint = requireText(fingerprint, 'invalid_purchase_token_fingerprint');
    const trustedToken = requireText(token, 'invalid_purchase_token', 4096);
    if (this.#fingerprintedTokens.has(trustedFingerprint) && this.#fingerprintedTokens.get(trustedFingerprint) !== trustedToken) {
      throw deny('purchase_token_fingerprint_collision');
    }
    this.#fingerprintedTokens.set(trustedFingerprint, trustedToken);
    const reference = `memory-vault:${randomUUID()}`;
    this.#entries.set(reference, Object.freeze({ fingerprint: trustedFingerprint, token: trustedToken }));
    return reference;
  }

  async retrieve(reference) {
    const entry = this.#entries.get(memoryVaultReference(reference));
    if (!entry) throw deny('purchase_token_not_available');
    return entry.token;
  }

  async discard(reference) {
    if (this.discardFailuresRemaining > 0) {
      this.discardFailuresRemaining -= 1;
      throw deny('purchase_token_cleanup_unavailable');
    }
    const trustedReference = memoryVaultReference(reference);
    const entry = this.#entries.get(trustedReference);
    if (!entry) return;
    this.#entries.delete(trustedReference);
    if (![...this.#entries.values()].some((value) => value.fingerprint === entry.fingerprint)) {
      this.#fingerprintedTokens.delete(entry.fingerprint);
    }
  }
}

function memoryVaultReference(reference) {
  const text = requireText(reference, 'invalid_token_reference');
  if (!text.startsWith('memory-vault:')) throw deny('invalid_token_reference');
  return text;
}
