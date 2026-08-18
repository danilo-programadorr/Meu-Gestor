import { createHash } from 'node:crypto';
import { deny, PrivacyBackendFailure } from './errors.mjs';
import { DEFAULT_PRIVACY_MANIFEST, isFinancialTarget, validatePrivacyManifest } from './manifest.mjs';
import { OperationIdGenerator } from './gateways.mjs';

const MAX_AUTH_AGE_MS = 5 * 60 * 1000;
const EXTERNAL_LEASE_MS = 30 * 1000;

export class PrivacyOperationProcessor {
  constructor({ storage, clock, sessionGateway, authGateway, receiptIdGenerator, operationIdGenerator = new OperationIdGenerator(), manifest = DEFAULT_PRIVACY_MANIFEST, batchSize = 25 }) {
    validatePrivacyManifest(manifest);
    if (!storage || !clock || !sessionGateway || !authGateway || !receiptIdGenerator || !Number.isInteger(batchSize) || batchSize < 1 || batchSize > 100) {
      throw new Error('privacy_processor_configuration_invalid');
    }
    this.storage = storage;
    this.clock = clock;
    this.sessionGateway = sessionGateway;
    this.authGateway = authGateway;
    this.receiptIdGenerator = receiptIdGenerator;
    this.operationIdGenerator = operationIdGenerator;
    this.manifest = manifest;
    this.batchSize = batchSize;
  }

  async request({ actor, type, confirmationPhrase, idempotencyKey }) {
    this.#assertType(type);
    this.#assertActor(actor, actor?.uid);
    if (confirmationPhrase !== phraseFor(type) || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) throw deny('privacy_invalid_confirmation');
    const ownerId = actor.uid;
    const requestFingerprint = fingerprint(ownerId, type, idempotencyKey);
    const now = this.#now();
    return this.#recoverAfterCommit(async () => this.storage.transaction((draft) => {
      const completedReceiptId = draft.completedRequests.get(requestFingerprint);
      if (completedReceiptId) return presentReceipt(draft.receipts.get(completedReceiptId));
      const existingId = draft.requestIndex.get(requestFingerprint);
      if (existingId) return presentOperation(draft.operations.get(existingId));
      if (draft.activeByOwner.has(ownerId)) throw deny('privacy_operation_conflict');
      const operation = {
        id: this.operationIdGenerator.next(), ownerId, type, state: 'prepared', revision: 1,
        createdAt: now, updatedAt: now, cursor: null, resumeState: null, authStage: null,
      };
      draft.operations.set(operation.id, operation);
      draft.activeByOwner.set(ownerId, operation.id);
      draft.requestIndex.set(requestFingerprint, operation.id);
      return presentOperation(operation);
    }), ownerId, requestFingerprint);
  }

  async advance({ actor, operationId }) {
    const operation = await this.#ownedOperation(actor, operationId);
    if (operation.state === 'failed') return this.retry({ actor, operationId });
    if (operation.state === 'prepared') return this.#confirm(actor.uid, operationId);
    if (operation.state === 'confirmed') return this.#lock(actor.uid, operationId);
    if (operation.state === 'locked') return this.#beginDeleting(actor.uid, operationId);
    if (operation.state === 'deleting') return this.#deleteBatch(actor.uid, operationId);
    if (operation.state === 'authDeletionPending') return this.#processAuthenticationDeletion(actor, operationId);
    throw deny('privacy_invalid_transition');
  }

  async retry({ actor, operationId }) {
    const operation = await this.#ownedOperation(actor, operationId);
    if (operation.state !== 'failed') return presentOperation(operation);
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const current = this.#requireOwnedDraft(draft, actor.uid, operationId);
      current.state = current.resumeState;
      current.resumeState = null;
      current.updatedAt = this.#now();
      current.revision += 1;
      return presentOperation(current);
    }), actor.uid);
  }

  /// Retorna somente o estado público da operação do próprio solicitante.
  /// O cursor completo, UID, chave de idempotência e etapas internas nunca
  /// atravessam a fronteira callable.
  async status({ actor, operationId }) {
    return presentOperation(await this.#ownedOperation(actor, operationId));
  }

  async #lock(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      if (operation.state !== 'confirmed') return presentOperation(operation);
      draft.locks.set(ownerId, { scope: operation.type === 'accountDeletion' ? 'all' : 'financial' });
      operation.state = 'locked'; operation.updatedAt = this.#now(); operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  async #confirm(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      if (operation.state !== 'prepared') return presentOperation(operation);
      operation.state = 'confirmed'; operation.updatedAt = this.#now(); operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  async #beginDeleting(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      if (operation.state !== 'locked') return presentOperation(operation);
      operation.state = 'deleting';
      operation.cursor = { targetIndex: 0, afterDocumentId: null };
      operation.updatedAt = this.#now(); operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  async #deleteBatch(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      if (operation.state !== 'deleting') return presentOperation(operation);
      const targets = this.manifest[operation.type];
      const cursor = operation.cursor;
      if (!cursor || !Number.isInteger(cursor.targetIndex) || cursor.targetIndex < 0 || cursor.targetIndex > targets.length) throw deny('privacy_cursor_invalid');
      if (cursor.targetIndex === targets.length) return this.#afterDataDeletion(draft, operation);
      const target = targets[cursor.targetIndex];
      const documents = [...draft.documents.get(target).values()]
        .filter((document) => document.ownerId === ownerId && (cursor.afterDocumentId === null || document.documentId > cursor.afterDocumentId))
        .sort((left, right) => left.documentId.localeCompare(right.documentId));
      const batch = documents.slice(0, this.batchSize);
      for (const document of batch) draft.documents.get(target).delete(`${ownerId}:${document.documentId}`);
      const hasMore = documents.length > batch.length;
      operation.cursor = hasMore
        ? { targetIndex: cursor.targetIndex, afterDocumentId: batch.at(-1).documentId }
        : { targetIndex: cursor.targetIndex + 1, afterDocumentId: null };
      operation.updatedAt = this.#now(); operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  #afterDataDeletion(draft, operation) {
    if (operation.type === 'financialReset') return this.#completeDraft(draft, operation);
    operation.state = 'authDeletionPending'; operation.authStage = 'revokeSessions';
    operation.updatedAt = this.#now(); operation.revision += 1;
    return presentOperation(operation);
  }

  async #processAuthenticationDeletion(actor, operationId) {
    const ownerId = actor.uid;
    const operation = await this.#ownedOperation(actor, operationId);
    if (operation.authStage === 'revokeSessions') {
      await this.#claimExternal(ownerId, operationId, 'revokeSessions');
      try { await this.sessionGateway.revokeRefreshTokens(ownerId); }
      catch (error) { return this.#failExternal(ownerId, operationId, 'revokeSessions', error); }
      return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
        const current = this.#requireOwnedDraft(draft, ownerId, operationId);
        current.authStage = 'deleteAuth'; current.externalLease = null; current.updatedAt = this.#now(); current.revision += 1;
        return presentOperation(current);
      }), ownerId);
    }
    if (operation.authStage === 'deleteAuth') {
      await this.#claimExternal(ownerId, operationId, 'deleteAuth');
      try { await this.authGateway.deleteUser(ownerId); }
      catch (error) { return this.#failExternal(ownerId, operationId, 'deleteAuth', error); }
      return this.#recoverAfterCommit(() => this.storage.transaction((draft) => this.#completeDraft(draft, this.#requireOwnedDraft(draft, ownerId, operationId))), ownerId, undefined, operationId);
    }
    throw deny('privacy_inconsistent_state');
  }

  async #claimExternal(ownerId, operationId, stage) {
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      const now = this.#now();
      const currentLease = operation.externalLease;
      const leaseIsActive = currentLease && currentLease.stage === stage &&
        now.getTime() - new Date(currentLease.claimedAt).getTime() <= EXTERNAL_LEASE_MS;
      if (operation.state !== 'authDeletionPending' || operation.authStage !== stage || (currentLease && leaseIsActive)) throw deny('privacy_operation_in_progress');
      operation.externalLease = { stage, claimedAt: now }; operation.updatedAt = now; operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  async #failExternal(ownerId, operationId, stage, error) {
    if (!(error instanceof PrivacyBackendFailure)) throw error;
    return this.#recoverAfterCommit(() => this.storage.transaction((draft) => {
      const operation = this.#requireOwnedDraft(draft, ownerId, operationId);
      operation.state = 'failed'; operation.resumeState = 'authDeletionPending'; operation.authStage = stage;
      operation.externalLease = null; operation.updatedAt = this.#now(); operation.revision += 1;
      return presentOperation(operation);
    }), ownerId);
  }

  #completeDraft(draft, operation) {
    const completedAt = this.#now();
    const receipt = {
      receiptId: this.receiptIdGenerator.next(), type: operation.type,
      result: operation.type === 'financialReset' ? 'resetCompleted' : 'accountDeleted',
      completedAt, expiresAt: new Date(completedAt.getTime() + 30 * 24 * 60 * 60 * 1000),
    };
    const requestFingerprint = [...draft.requestIndex.entries()].find(([, id]) => id === operation.id)?.[0];
    if (!requestFingerprint) throw deny('privacy_inconsistent_state');
    draft.receipts.set(receipt.receiptId, receipt);
    draft.completedRequests.set(requestFingerprint, receipt.receiptId);
    draft.requestIndex.delete(requestFingerprint); draft.activeByOwner.delete(operation.ownerId); draft.locks.delete(operation.ownerId);
    draft.operations.set(operation.id, { id: operation.id, type: operation.type, state: 'completed', receiptId: receipt.receiptId, completedAt });
    draft.audits.push({ type: operation.type, state: 'completed', completedAt, result: receipt.result });
    return presentReceipt(receipt);
  }

  async #ownedOperation(actor, operationId) {
    this.#assertActor(actor, actor?.uid);
    const state = await this.storage.snapshot();
    const operation = state.operations.get(operationId);
    if (!operation || operation.ownerId !== actor.uid) throw deny('privacy_operation_not_found');
    return operation;
  }

  #requireOwnedDraft(draft, ownerId, operationId) {
    const operation = draft.operations.get(operationId);
    if (!operation || operation.ownerId !== ownerId || draft.activeByOwner.get(ownerId) !== operationId) throw deny('privacy_operation_not_found');
    return operation;
  }

  #assertActor(actor, requestedOwnerId) {
    const now = this.#now();
    const authenticatedAt = actor?.authenticatedAt instanceof Date ? actor.authenticatedAt : null;
    if (!actor?.authenticated || !actor?.appCheckVerified || !actor?.emailVerified || !actor?.legalProfileVerified ||
        !actor?.uid || actor.uid !== requestedOwnerId || !authenticatedAt || authenticatedAt > now || now - authenticatedAt > MAX_AUTH_AGE_MS) {
      throw deny('privacy_authorization_denied');
    }
  }

  #assertType(type) { if (type !== 'financialReset' && type !== 'accountDeletion') throw deny('privacy_invalid_request'); }
  #now() { const now = this.clock.now(); if (!(now instanceof Date) || Number.isNaN(now.valueOf())) throw deny('privacy_clock_invalid'); return new Date(now); }
  async #recoverAfterCommit(operation, ownerId, requestFingerprint, operationId) {
    try { return await operation(); }
    catch (error) {
      if (!(error instanceof PrivacyBackendFailure) || error.code !== 'privacy_storage_confirmation_timeout') throw error;
      const state = await this.storage.snapshot();
      if (requestFingerprint && state.completedRequests.has(requestFingerprint)) return presentReceipt(state.receipts.get(state.completedRequests.get(requestFingerprint)));
      const activeId = state.activeByOwner.get(ownerId);
      if (activeId) return presentOperation(state.operations.get(activeId));
      const completed = operationId ? state.operations.get(operationId) : null;
      if (completed?.state === 'completed') return presentReceipt(state.receipts.get(completed.receiptId));
      throw error;
    }
  }
}

const phraseFor = (type) => type === 'financialReset' ? 'RESETAR DADOS FINANCEIROS' : 'EXCLUIR MINHA CONTA';
const fingerprint = (ownerId, type, idempotencyKey) => createHash('sha256').update(`privacy-idempotency-v1:${ownerId}:${type}:${idempotencyKey}`).digest('hex');
const presentOperation = (operation) => ({
  operationId: operation.id,
  type: operation.type,
  state: operation.state,
  revision: operation.revision,
  createdAt: operation.createdAt ? new Date(operation.createdAt) : null,
  updatedAt: operation.updatedAt ? new Date(operation.updatedAt) : null,
  cursor: operation.cursor ? { targetIndex: operation.cursor.targetIndex } : null,
});
const presentReceipt = (receipt) => ({ state: 'completed', receipt: { receiptId: receipt.receiptId, type: receipt.type, result: receipt.result, completedAt: new Date(receipt.completedAt), expiresAt: new Date(receipt.expiresAt) } });
