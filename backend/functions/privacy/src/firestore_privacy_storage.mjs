import { createHash } from 'node:crypto';

import { deny } from '../../../privacy/src/errors.mjs';
import { PrivacyTransactionalStorage } from '../../../privacy/src/storage.mjs';

const RECEIPTS_COLLECTION = '_privacyReceipts';
const OPERATION_DOCUMENT = 'current';
const LOCK_DOCUMENT = 'current';

const SUBCOLLECTION_TARGETS = Object.freeze({
  accounts: 'accounts',
  categories: 'categories',
  transactions: 'transactions',
  payables: 'payables',
  receivables: 'receivables',
  investmentPortfolios: 'investmentPortfolios',
  investmentAssets: 'investmentAssets',
  investmentOperations: 'investmentOperations',
  investmentIncomeEvents: 'investmentIncomeEvents',
});

/// Persistência Admin paginada. Cada transição lê e confirma o documento
/// owner-scoped na mesma transação; recibos concluídos não carregam UID,
/// chave de idempotência, cursor ou conteúdo financeiro.
export class FirestorePrivacyStorage extends PrivacyTransactionalStorage {
  constructor({ firestore, Timestamp, externalTargets = {} }) {
    super();
    if (!firestore || typeof firestore.runTransaction !== 'function' ||
        !Timestamp || typeof Timestamp.fromDate !== 'function') {
      throw new TypeError('privacy_firestore_dependencies_invalid');
    }
    this.firestore = firestore;
    this.Timestamp = Timestamp;
    this.externalTargets = Object.freeze({ ...externalTargets });
  }

  async transaction() { throw new Error('privacy_firestore_raw_transaction_forbidden'); }
  async snapshot() { throw new Error('privacy_firestore_snapshot_forbidden'); }

  async prepare({ ownerId, type, requestFingerprint, operationId, now }) {
    validateIdentity(ownerId, operationId);
    return this.firestore.runTransaction(async (transaction) => {
      const refs = this.#refs(ownerId, operationId);
      const [receiptSnapshot, operationSnapshot] = await Promise.all([
        transaction.get(refs.receipt),
        transaction.get(refs.operation),
      ]);
      if (receiptSnapshot.exists) return presentReceipt(operationId, decodeReceipt(receiptSnapshot.data()));
      if (operationSnapshot.exists) {
        const existing = decodeOperation(operationSnapshot.data());
        if (existing.ownerId !== ownerId || existing.requestFingerprint !== requestFingerprint) {
          throw deny('privacy_operation_conflict');
        }
        return presentOperation(existing);
      }
      const operation = {
        id: operationId,
        ownerId,
        type,
        state: 'prepared',
        revision: 1,
        createdAt: now,
        updatedAt: now,
        cursor: null,
        resumeState: null,
        authStage: null,
        externalLease: null,
        requestFingerprint,
      };
      transaction.create(refs.operation, encodeOperation(operation, this.Timestamp));
      return presentOperation(operation);
    });
  }

  async readOwned({ ownerId, operationId }) {
    validateIdentity(ownerId, operationId);
    const snapshot = await this.#operation(ownerId).get();
    if (!snapshot.exists) throw deny('privacy_operation_not_found');
    const operation = decodeOperation(snapshot.data());
    if (operation.ownerId !== ownerId || operation.id !== operationId) {
      throw deny('privacy_operation_not_found');
    }
    return operation;
  }

  async updateOwned({ ownerId, operationId, update, lockScope }) {
    validateIdentity(ownerId, operationId);
    if (typeof update !== 'function') throw deny('privacy_inconsistent_state');
    return this.firestore.runTransaction(async (transaction) => {
      const refs = this.#refs(ownerId, operationId);
      const snapshot = await transaction.get(refs.operation);
      const operation = requireOwnedSnapshot(snapshot, ownerId, operationId);
      update(operation);
      transaction.set(refs.operation, encodeOperation(operation, this.Timestamp));
      if (lockScope !== undefined) {
        if (!['financial', 'all'].includes(lockScope)) throw deny('privacy_inconsistent_state');
        transaction.set(refs.lock, {
          scope: lockScope === 'all' ? 'accountDeletion' : 'financialReset',
          ownerId,
          createdAt: this.Timestamp.fromDate(operation.updatedAt),
          schemaVersion: 1,
        });
      }
      return presentOperation(operation);
    });
  }

  async deleteOwnedBatch({ ownerId, operationId, target, targetIndex, batchSize, now }) {
    validateIdentity(ownerId, operationId);
    if (!Number.isInteger(targetIndex) || targetIndex < 0 ||
        !Number.isInteger(batchSize) || batchSize < 1 || batchSize > 100) {
      throw deny('privacy_cursor_invalid');
    }
    const external = this.externalTargets[target];
    if (external) {
      await external.deleteOwner({ ownerId });
      return this.#advanceExternalTarget({ ownerId, operationId, targetIndex, now });
    }
    return this.firestore.runTransaction(async (transaction) => {
      const operationRef = this.#operation(ownerId);
      const operationSnapshot = await transaction.get(operationRef);
      const operation = requireOwnedSnapshot(operationSnapshot, ownerId, operationId);
      requireDeletingCursor(operation, targetIndex);
      const descriptor = this.#descriptor(ownerId, target);
      const snapshots = descriptor.kind === 'document'
        ? [await transaction.get(descriptor.reference)].filter((snapshot) => snapshot.exists)
        : (await transaction.get(descriptor.query.limit(batchSize))).docs;
      for (const snapshot of snapshots) {
        transaction.delete(snapshot.ref);
        if (target === 'investmentAssets') {
          transaction.delete(this.firestore.doc(`_marketQuoteDemands/${quoteDemandId(ownerId, snapshot.id)}`));
        }
      }
      const hasMore = descriptor.kind === 'query' && snapshots.length === batchSize;
      if (!hasMore) operation.cursor = { targetIndex: targetIndex + 1, afterDocumentId: null };
      operation.updatedAt = now;
      operation.revision += 1;
      transaction.set(operationRef, encodeOperation(operation, this.Timestamp));
      return presentOperation(operation);
    });
  }

  async complete({ ownerId, operationId, receipt }) {
    validateIdentity(ownerId, operationId);
    return this.firestore.runTransaction(async (transaction) => {
      const refs = this.#refs(ownerId, operationId);
      const [receiptSnapshot, operationSnapshot] = await Promise.all([
        transaction.get(refs.receipt),
        transaction.get(refs.operation),
      ]);
      if (receiptSnapshot.exists) return presentReceipt(operationId, decodeReceipt(receiptSnapshot.data()));
      const operation = requireOwnedSnapshot(operationSnapshot, ownerId, operationId);
      if (operation.type !== receipt.type) throw deny('privacy_inconsistent_state');
      transaction.create(refs.receipt, encodeReceipt(receipt, this.Timestamp));
      transaction.delete(refs.operation);
      transaction.delete(refs.lock);
      return presentReceipt(operationId, receipt);
    });
  }

  async recover({ ownerId, operationId }) {
    if (!operationId) return null;
    validateIdentity(ownerId, operationId);
    const refs = this.#refs(ownerId, operationId);
    const [operationSnapshot, receiptSnapshot] = await Promise.all([
      refs.operation.get(), refs.receipt.get(),
    ]);
    if (operationSnapshot.exists) {
      const operation = decodeOperation(operationSnapshot.data());
      if (operation.ownerId === ownerId && operation.id === operationId) return presentOperation(operation);
      return null;
    }
    return receiptSnapshot.exists ? presentReceipt(operationId, decodeReceipt(receiptSnapshot.data())) : null;
  }

  async #advanceExternalTarget({ ownerId, operationId, targetIndex, now }) {
    return this.firestore.runTransaction(async (transaction) => {
      const reference = this.#operation(ownerId);
      const snapshot = await transaction.get(reference);
      const operation = requireOwnedSnapshot(snapshot, ownerId, operationId);
      requireDeletingCursor(operation, targetIndex);
      operation.cursor = { targetIndex: targetIndex + 1, afterDocumentId: null };
      operation.updatedAt = now;
      operation.revision += 1;
      transaction.set(reference, encodeOperation(operation, this.Timestamp));
      return presentOperation(operation);
    });
  }

  #descriptor(ownerId, target) {
    if (Object.hasOwn(SUBCOLLECTION_TARGETS, target)) {
      const collection = this.firestore.collection(`users/${ownerId}/${SUBCOLLECTION_TARGETS[target]}`);
      return { kind: 'query', query: collection };
    }
    if (target === 'assistantSettings') {
      return { kind: 'document', reference: this.firestore.doc(`users/${ownerId}/assistantSettings/remote`) };
    }
    if (target === 'premiumEntitlement') {
      return { kind: 'document', reference: this.firestore.doc(`users/${ownerId}/entitlements/premium`) };
    }
    if (target === 'systemAdmin') {
      return { kind: 'document', reference: this.firestore.doc(`system_admins/${ownerId}`) };
    }
    if (target === 'premiumClosedTestTesters') {
      return { kind: 'document', reference: this.firestore.doc(`_premiumClosedTestTesters/${ownerId}`) };
    }
    if (target === 'premiumClosedTestGrants') {
      return { kind: 'query', query: this.firestore.collection('_premiumClosedTestGrants').where('ownerId', '==', ownerId) };
    }
    if (target === 'userProfile') {
      return { kind: 'document', reference: this.firestore.doc(`users/${ownerId}`) };
    }
    throw deny('privacy_manifest_unknown_target');
  }

  #operation(ownerId) {
    return this.firestore.doc(`users/${ownerId}/privacyOperations/${OPERATION_DOCUMENT}`);
  }

  #refs(ownerId, operationId) {
    return Object.freeze({
      operation: this.#operation(ownerId),
      lock: this.firestore.doc(`users/${ownerId}/privacyLocks/${LOCK_DOCUMENT}`),
      receipt: this.firestore.doc(`${RECEIPTS_COLLECTION}/${operationId}`),
    });
  }
}

function validateIdentity(ownerId, operationId) {
  if (typeof ownerId !== 'string' || ownerId.length < 1 || ownerId.length > 128 || ownerId.includes('/') ||
      typeof operationId !== 'string' || !/^privacy-operation-[a-f0-9-]{16,}$/.test(operationId)) {
    throw deny('privacy_invalid_request');
  }
}

function requireOwnedSnapshot(snapshot, ownerId, operationId) {
  if (!snapshot.exists) throw deny('privacy_operation_not_found');
  const operation = decodeOperation(snapshot.data());
  if (operation.ownerId !== ownerId || operation.id !== operationId) throw deny('privacy_operation_not_found');
  return operation;
}

function requireDeletingCursor(operation, targetIndex) {
  if (operation.state !== 'deleting' || operation.cursor?.targetIndex !== targetIndex) {
    throw deny('privacy_invalid_transition');
  }
}

function encodeOperation(operation, Timestamp) {
  return {
    operationId: operation.id,
    ownerId: operation.ownerId,
    type: operation.type,
    state: operation.state,
    revision: operation.revision,
    createdAt: Timestamp.fromDate(operation.createdAt),
    updatedAt: Timestamp.fromDate(operation.updatedAt),
    cursor: operation.cursor,
    resumeState: operation.resumeState,
    authStage: operation.authStage,
    externalLease: operation.externalLease === null || operation.externalLease === undefined
      ? null
      : { stage: operation.externalLease.stage, claimedAt: Timestamp.fromDate(new Date(operation.externalLease.claimedAt)) },
    requestFingerprint: operation.requestFingerprint,
    schemaVersion: 1,
  };
}

function decodeOperation(value) {
  if (!value || value.schemaVersion !== 1 || typeof value.operationId !== 'string' ||
      typeof value.ownerId !== 'string' || !['financialReset', 'accountDeletion'].includes(value.type) ||
      !['prepared', 'confirmed', 'locked', 'deleting', 'authDeletionPending', 'failed'].includes(value.state) ||
      !Number.isInteger(value.revision) || value.revision < 1 ||
      !/^[a-f0-9]{64}$/.test(value.requestFingerprint)) {
    throw deny('privacy_inconsistent_state');
  }
  const createdAt = timestampDate(value.createdAt);
  const updatedAt = timestampDate(value.updatedAt);
  const externalLease = value.externalLease === null ? null : {
    stage: value.externalLease?.stage,
    claimedAt: timestampDate(value.externalLease?.claimedAt),
  };
  return {
    id: value.operationId,
    ownerId: value.ownerId,
    type: value.type,
    state: value.state,
    revision: value.revision,
    createdAt,
    updatedAt,
    cursor: value.cursor === null ? null : structuredClone(value.cursor),
    resumeState: value.resumeState ?? null,
    authStage: value.authStage ?? null,
    externalLease,
    requestFingerprint: value.requestFingerprint,
  };
}

function encodeReceipt(receipt, Timestamp) {
  return {
    receiptId: receipt.receiptId,
    type: receipt.type,
    result: receipt.result,
    completedAt: Timestamp.fromDate(receipt.completedAt),
    expiresAt: Timestamp.fromDate(receipt.expiresAt),
    schemaVersion: 1,
  };
}

function decodeReceipt(value) {
  if (!value || value.schemaVersion !== 1 || typeof value.receiptId !== 'string' ||
      !['financialReset', 'accountDeletion'].includes(value.type) ||
      !['resetCompleted', 'accountDeleted'].includes(value.result)) {
    throw deny('privacy_inconsistent_state');
  }
  return {
    receiptId: value.receiptId,
    type: value.type,
    result: value.result,
    completedAt: timestampDate(value.completedAt),
    expiresAt: timestampDate(value.expiresAt),
  };
}

function timestampDate(value) {
  const date = value?.toDate?.();
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) throw deny('privacy_inconsistent_state');
  return date;
}

function quoteDemandId(ownerId, assetId) {
  return createHash('sha256').update(`${ownerId}\u0000${assetId}`, 'utf8').digest('hex');
}

function presentOperation(operation) {
  return {
    operationId: operation.id,
    type: operation.type,
    state: operation.state,
    revision: operation.revision,
    createdAt: new Date(operation.createdAt),
    updatedAt: new Date(operation.updatedAt),
  };
}

function presentReceipt(operationId, receipt) {
  return {
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
  };
}
