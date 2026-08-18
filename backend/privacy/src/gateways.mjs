import { deny } from './errors.mjs';

export class ServerClock {
  now() { throw new Error('ServerClock.now must be implemented'); }
}

export class FixedServerClock extends ServerClock {
  constructor(instant) { super(); this.instant = instant; }
  now() { return new Date(this.instant); }
  set(instant) { this.instant = instant; }
}

export class SessionRevocationGateway {
  async revokeRefreshTokens(_ownerId) { throw new Error('SessionRevocationGateway.revokeRefreshTokens must be implemented'); }
}

export class FirebaseAuthDeletionGateway {
  async deleteUser(_ownerId) { throw new Error('FirebaseAuthDeletionGateway.deleteUser must be implemented'); }
}

export class DeterministicSessionGateway extends SessionRevocationGateway {
  calls = [];
  attempts = [];
  failNext = false;
  async revokeRefreshTokens(ownerId) {
    this.attempts.push(ownerId);
    if (this.failNext) { this.failNext = false; throw deny('privacy_session_revocation_unavailable'); }
    this.calls.push(ownerId);
  }
}

export class DeterministicAuthDeletionGateway extends FirebaseAuthDeletionGateway {
  calls = [];
  attempts = [];
  deleted = new Set();
  failNext = false;
  async deleteUser(ownerId) {
    this.attempts.push(ownerId);
    if (this.failNext) { this.failNext = false; throw deny('privacy_auth_deletion_unavailable'); }
    this.calls.push(ownerId);
    this.deleted.add(ownerId);
  }
}

export class ReceiptIdGenerator {
  next() { throw new Error('ReceiptIdGenerator.next must be implemented'); }
}

export class DeterministicReceiptIdGenerator extends ReceiptIdGenerator {
  #sequence = 0;
  next() { this.#sequence += 1; return `receipt-synthetic-${String(this.#sequence).padStart(16, '0')}`; }
}

export class OperationIdGenerator {
  #sequence = 0;
  next() { this.#sequence += 1; return `privacy-operation-${String(this.#sequence).padStart(16, '0')}`; }
}
