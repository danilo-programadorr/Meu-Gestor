import { createHmac } from 'node:crypto';
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
  async store(_fingerprint, _token) {
    throw new Error('PurchaseTokenVault.store must be implemented');
  }

  async retrieve(_reference) {
    throw new Error('PurchaseTokenVault.retrieve must be implemented');
  }
}

export class InMemoryPurchaseTokenVault extends PurchaseTokenVault {
  #tokens = new Map();

  constructor() {
    super();
  }

  async store(fingerprint, token) {
    if (this.#tokens.has(fingerprint) && this.#tokens.get(fingerprint) !== token) {
      throw deny('purchase_token_fingerprint_collision');
    }
    this.#tokens.set(fingerprint, token);
    return `memory-vault:${fingerprint}`;
  }

  async retrieve(reference) {
    const fingerprint = requireText(reference, 'invalid_token_reference').replace('memory-vault:', '');
    const token = this.#tokens.get(fingerprint);
    if (!token) throw deny('purchase_token_not_available');
    return token;
  }
}
