import { deny } from './errors.mjs';

export class SubscriptionTransactionalStorage {
  async transaction(_operation) {
    throw new Error('SubscriptionTransactionalStorage.transaction must be implemented');
  }

  async snapshot() {
    throw new Error('SubscriptionTransactionalStorage.snapshot must be implemented');
  }
}

export class InMemorySubscriptionStorage extends SubscriptionTransactionalStorage {
  #state = {
    entitlements: new Map(), bindings: new Map(), events: new Map(),
    rtdnInbox: new Map(), acknowledgementOutbox: new Map(), grants: new Map(),
  };
  #queue = Promise.resolve();
  failBeforeCommit = false;
  failAfterCommit = false;

  constructor() {
    super();
  }

  async transaction(operation) {
    const run = async () => {
      if (this.failBeforeCommit) { this.failBeforeCommit = false; throw deny('storage_unavailable_before_commit'); }
      const draft = structuredClone(this.#state);
      const result = await operation(draft);
      this.#state = draft;
      if (this.failAfterCommit) { this.failAfterCommit = false; throw deny('storage_confirmation_timeout'); }
      return structuredClone(result);
    };
    const pending = this.#queue.then(run, run);
    this.#queue = pending.catch(() => undefined);
    return pending;
  }

  async snapshot() { await this.#queue; return structuredClone(this.#state); }
  async entitlement(ownerId) { return (await this.snapshot()).entitlements.get(ownerId) ?? null; }
  async event(eventId) { return (await this.snapshot()).events.get(eventId) ?? null; }
  async binding(fingerprint) { return (await this.snapshot()).bindings.get(fingerprint) ?? null; }
}
