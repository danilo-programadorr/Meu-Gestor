import { deny } from './errors.mjs';
import { PRIVACY_TARGETS, isFinancialTarget } from './manifest.mjs';

export class PrivacyTransactionalStorage {
  async transaction(_operation) { throw new Error('PrivacyTransactionalStorage.transaction must be implemented'); }
  async snapshot() { throw new Error('PrivacyTransactionalStorage.snapshot must be implemented'); }
}

export class InMemoryPrivacyStorage extends PrivacyTransactionalStorage {
  #state = {
    operations: new Map(), activeByOwner: new Map(), requestIndex: new Map(),
    completedRequests: new Map(), locks: new Map(), receipts: new Map(), audits: [],
    documents: new Map(PRIVACY_TARGETS.map((target) => [target, new Map()])),
  };
  #queue = Promise.resolve();
  failBeforeCommit = false;
  failAfterCommit = false;

  async transaction(operation) {
    const run = async () => {
      if (this.failBeforeCommit) {
        this.failBeforeCommit = false;
        throw deny('privacy_storage_unavailable_before_commit');
      }
      const draft = structuredClone(this.#state);
      const result = await operation(draft);
      this.#state = draft;
      if (this.failAfterCommit) {
        this.failAfterCommit = false;
        throw deny('privacy_storage_confirmation_timeout');
      }
      return structuredClone(result);
    };
    const pending = this.#queue.then(run, run);
    this.#queue = pending.catch(() => undefined);
    return pending;
  }

  async snapshot() { await this.#queue; return structuredClone(this.#state); }

  async seed({ target, ownerId, documentId, value = {} }) {
    if (!PRIVACY_TARGETS.includes(target) || !ownerId || !documentId) throw deny('privacy_seed_invalid');
    return this.transaction((draft) => {
      draft.documents.get(target).set(`${ownerId}:${documentId}`, { ownerId, documentId, value });
    });
  }

  async listOwned(target, ownerId) {
    const state = await this.snapshot();
    return [...state.documents.get(target).values()]
      .filter((document) => document.ownerId === ownerId)
      .sort((left, right) => left.documentId.localeCompare(right.documentId));
  }

  async writeAllowed({ target, ownerId }) {
    const state = await this.snapshot();
    const lock = state.locks.get(ownerId);
    if (!lock) return true;
    return lock.scope !== 'all' && !isFinancialTarget(target);
  }
}
