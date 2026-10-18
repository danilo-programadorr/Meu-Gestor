import { deny } from './errors.mjs';
import { PRIVACY_TARGETS, isFinancialTarget } from './manifest.mjs';

export class PrivacyTransactionalStorage {
  async transaction(_operation) { throw new Error('PrivacyTransactionalStorage.transaction must be implemented'); }
  async snapshot() { throw new Error('PrivacyTransactionalStorage.snapshot must be implemented'); }

  async prepare(_request) { throw new Error('PrivacyTransactionalStorage.prepare must be implemented'); }
  async readOwned(_request) { throw new Error('PrivacyTransactionalStorage.readOwned must be implemented'); }
  async updateOwned(_request) { throw new Error('PrivacyTransactionalStorage.updateOwned must be implemented'); }
  async deleteOwnedBatch(_request) { throw new Error('PrivacyTransactionalStorage.deleteOwnedBatch must be implemented'); }
  async complete(_request) { throw new Error('PrivacyTransactionalStorage.complete must be implemented'); }
  async recover(_request) { throw new Error('PrivacyTransactionalStorage.recover must be implemented'); }
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

  // Abertura do contrato persistente: o domínio expressa intenção e o
  // adaptador decide como confirmar atomicamente cada transição.
  async prepare({ ownerId, type, requestFingerprint, operationId, now }) {
    return this.transaction((draft) => {
      const completedReceiptId = draft.completedRequests.get(requestFingerprint);
      if (completedReceiptId) {
        const completedOperation = [...draft.operations.values()]
          .find((candidate) => candidate.receiptId === completedReceiptId);
        return presentReceipt(completedOperation?.id ?? operationId, draft.receipts.get(completedReceiptId));
      }
      const existingId = draft.requestIndex.get(requestFingerprint);
      if (existingId) return presentOperation(draft.operations.get(existingId));
      if (draft.activeByOwner.has(ownerId)) throw deny('privacy_operation_conflict');
      const operation = {
        id: operationId, ownerId, type, state: 'prepared', revision: 1,
        createdAt: now, updatedAt: now, cursor: null, resumeState: null,
        authStage: null, externalLease: null, requestFingerprint,
      };
      draft.operations.set(operation.id, operation);
      draft.activeByOwner.set(ownerId, operation.id);
      draft.requestIndex.set(requestFingerprint, operation.id);
      return presentOperation(operation);
    });
  }

  async readOwned({ ownerId, operationId }) {
    const state = await this.snapshot();
    const operation = state.operations.get(operationId);
    if (!operation || operation.ownerId !== ownerId) throw deny('privacy_operation_not_found');
    return operation;
  }

  async updateOwned({ ownerId, operationId, update, lockScope }) {
    return this.transaction((draft) => {
      const operation = requireOwnedDraft(draft, ownerId, operationId);
      if (lockScope !== undefined) draft.locks.set(ownerId, { scope: lockScope });
      update(operation);
      return presentOperation(operation);
    });
  }

  async deleteOwnedBatch({ ownerId, operationId, target, batchSize, now }) {
    return this.transaction((draft) => {
      const operation = requireOwnedDraft(draft, ownerId, operationId);
      const cursor = operation.cursor;
      const documents = [...draft.documents.get(target).values()]
        .filter((document) => document.ownerId === ownerId &&
          (cursor.afterDocumentId === null || document.documentId > cursor.afterDocumentId))
        .sort((left, right) => left.documentId.localeCompare(right.documentId));
      const batch = documents.slice(0, batchSize);
      for (const document of batch) draft.documents.get(target).delete(`${ownerId}:${document.documentId}`);
      const hasMore = documents.length > batch.length;
      operation.cursor = hasMore
        ? { targetIndex: cursor.targetIndex, afterDocumentId: batch.at(-1).documentId }
        : { targetIndex: cursor.targetIndex + 1, afterDocumentId: null };
      operation.updatedAt = now;
      operation.revision += 1;
      return presentOperation(operation);
    });
  }

  async complete({ ownerId, operationId, receipt }) {
    return this.transaction((draft) => {
      const operation = requireOwnedDraft(draft, ownerId, operationId);
      const requestFingerprint = operation.requestFingerprint ??
        [...draft.requestIndex.entries()].find(([, id]) => id === operation.id)?.[0];
      if (!requestFingerprint) throw deny('privacy_inconsistent_state');
      draft.receipts.set(receipt.receiptId, receipt);
      draft.completedRequests.set(requestFingerprint, receipt.receiptId);
      draft.requestIndex.delete(requestFingerprint);
      draft.activeByOwner.delete(operation.ownerId);
      draft.locks.delete(operation.ownerId);
      draft.operations.set(operation.id, {
        id: operation.id, type: operation.type, state: 'completed',
        receiptId: receipt.receiptId, completedAt: receipt.completedAt,
      });
      draft.audits.push({
        type: operation.type, state: 'completed',
        completedAt: receipt.completedAt, result: receipt.result,
      });
      return presentReceipt(operation.id, receipt);
    });
  }

  async recover({ ownerId, requestFingerprint, operationId }) {
    const state = await this.snapshot();
    if (requestFingerprint && state.completedRequests.has(requestFingerprint)) {
      const receiptId = state.completedRequests.get(requestFingerprint);
      const completedOperation = [...state.operations.values()]
        .find((candidate) => candidate.receiptId === receiptId);
      return presentReceipt(completedOperation?.id ?? operationId, state.receipts.get(receiptId));
    }
    const activeId = state.activeByOwner.get(ownerId);
    if (activeId && (!operationId || activeId === operationId)) {
      return presentOperation(state.operations.get(activeId));
    }
    const completed = operationId ? state.operations.get(operationId) : null;
    if (completed?.state === 'completed') {
      return presentReceipt(operationId, state.receipts.get(completed.receiptId));
    }
    return null;
  }

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

function requireOwnedDraft(draft, ownerId, operationId) {
  const operation = draft.operations.get(operationId);
  if (!operation || operation.ownerId !== ownerId || draft.activeByOwner.get(ownerId) !== operationId) {
    throw deny('privacy_operation_not_found');
  }
  return operation;
}

const presentOperation = (operation) => ({
  operationId: operation.id,
  type: operation.type,
  state: operation.state,
  revision: operation.revision,
  createdAt: operation.createdAt ? new Date(operation.createdAt) : null,
  updatedAt: operation.updatedAt ? new Date(operation.updatedAt) : null,
  cursor: operation.cursor ? { targetIndex: operation.cursor.targetIndex } : null,
});

const presentReceipt = (operationId, receipt) => ({
  operationId,
  type: receipt.type,
  state: 'completed',
  receipt: {
    receiptId: receipt.receiptId,
    type: receipt.type,
    result: receipt.result,
    completedAt: new Date(receipt.completedAt),
    expiresAt: new Date(receipt.expiresAt),
  },
});
