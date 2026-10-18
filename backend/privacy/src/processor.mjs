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
    const operationId = this.operationIdGenerator.next(requestFingerprint);
    return this.#recoverAfterCommit(() => this.storage.prepare({
      ownerId, type, requestFingerprint, operationId, now,
    }), ownerId, requestFingerprint, operationId);
  }

  async advance({ actor, operationId }) {
    const operation = await this.#ownedOperation(actor, operationId);
    return this.#advanceOwned(operation);
  }

  /// Entrada exclusiva para um worker interno acionado por documento Admin.
  /// O ownerId vem do caminho confiável do evento, nunca do payload cliente.
  async process({ ownerId, operationId }) {
    if (typeof ownerId !== 'string' || !ownerId || typeof operationId !== 'string' || !operationId) {
      throw deny('privacy_invalid_request');
    }
    const operation = await this.storage.readOwned({ ownerId, operationId });
    if (operation.state === 'prepared') return presentOperation(operation);
    return this.#advanceOwned(operation);
  }

  async authorizeContinuation({ ownerId, operationId }) {
    const recovered = await this.storage.recover({ ownerId, operationId });
    return recovered?.type === 'accountDeletion' &&
      ['confirmed', 'locked', 'deleting', 'authDeletionPending', 'failed', 'completed'].includes(recovered.state);
  }

  async #advanceOwned(operation) {
    const operationId = operation.id;
    const ownerId = operation.ownerId;
    if (operation.state === 'failed') return this.#retryOwned(ownerId, operationId);
    if (operation.state === 'prepared') return this.#confirm(ownerId, operationId);
    if (operation.state === 'confirmed') return this.#lock(ownerId, operationId);
    if (operation.state === 'locked') return this.#beginDeleting(ownerId, operationId);
    if (operation.state === 'deleting') return this.#deleteBatch(ownerId, operationId);
    if (operation.state === 'authDeletionPending') return this.#processAuthenticationDeletion(ownerId, operationId);
    throw deny('privacy_invalid_transition');
  }

  async retry({ actor, operationId }) {
    const operation = await this.#ownedOperation(actor, operationId);
    if (operation.state !== 'failed') return presentOperation(operation);
    return this.#retryOwned(actor.uid, operationId);
  }

  async #retryOwned(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      update: (current) => {
      current.state = current.resumeState;
      current.resumeState = null;
      current.updatedAt = this.#now();
      current.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  /// Retorna somente o estado público da operação do próprio solicitante.
  /// O cursor completo, UID, chave de idempotência e etapas internas nunca
  /// atravessam a fronteira callable.
  async status({ actor, operationId }) {
    this.#assertActor(actor, actor?.uid);
    const recovered = await this.storage.recover({ ownerId: actor.uid, operationId });
    if (!recovered) throw deny('privacy_operation_not_found');
    return recovered;
  }

  async #lock(ownerId, operationId) {
    const current = await this.storage.readOwned({ ownerId, operationId });
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      lockScope: current.type === 'accountDeletion' ? 'all' : 'financial',
      update: (operation) => {
        if (operation.state !== 'confirmed') return;
        operation.state = 'locked'; operation.updatedAt = this.#now(); operation.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  async #confirm(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      update: (operation) => {
        if (operation.state !== 'prepared') return;
        operation.state = 'confirmed'; operation.updatedAt = this.#now(); operation.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  async #beginDeleting(ownerId, operationId) {
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      update: (operation) => {
        if (operation.state !== 'locked') return;
        operation.state = 'deleting';
        operation.cursor = { targetIndex: 0, afterDocumentId: null };
        operation.updatedAt = this.#now(); operation.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  async #deleteBatch(ownerId, operationId) {
    const operation = await this.storage.readOwned({ ownerId, operationId });
    if (operation.state !== 'deleting') return presentOperation(operation);
    const targets = this.manifest[operation.type];
    const cursor = operation.cursor;
    if (!cursor || !Number.isInteger(cursor.targetIndex) || cursor.targetIndex < 0 || cursor.targetIndex > targets.length) throw deny('privacy_cursor_invalid');
    if (cursor.targetIndex === targets.length) return this.#afterDataDeletion(operation);
    return this.#recoverAfterCommit(() => this.storage.deleteOwnedBatch({
      ownerId,
      operationId,
      target: targets[cursor.targetIndex],
      targetIndex: cursor.targetIndex,
      batchSize: this.batchSize,
      now: this.#now(),
    }), ownerId, undefined, operationId);
  }

  async #afterDataDeletion(operation) {
    if (operation.type === 'financialReset') return this.#complete(operation.ownerId, operation.id, operation.type);
    return this.storage.updateOwned({
      ownerId: operation.ownerId,
      operationId: operation.id,
      update: (current) => {
        current.state = 'authDeletionPending'; current.authStage = 'revokeSessions';
        current.updatedAt = this.#now(); current.revision += 1;
      },
    });
  }

  async #processAuthenticationDeletion(ownerId, operationId) {
    const operation = await this.storage.readOwned({ ownerId, operationId });
    if (operation.authStage === 'revokeSessions') {
      await this.#claimExternal(ownerId, operationId, 'revokeSessions');
      try { await this.sessionGateway.revokeRefreshTokens(ownerId); }
      catch (error) { return this.#failExternal(ownerId, operationId, 'revokeSessions', error); }
      return this.#recoverAfterCommit(() => this.storage.updateOwned({
        ownerId,
        operationId,
        update: (current) => {
        current.authStage = 'deleteAuth'; current.externalLease = null; current.updatedAt = this.#now(); current.revision += 1;
        },
      }), ownerId, undefined, operationId);
    }
    if (operation.authStage === 'deleteAuth') {
      await this.#claimExternal(ownerId, operationId, 'deleteAuth');
      try { await this.authGateway.deleteUser(ownerId); }
      catch (error) { return this.#failExternal(ownerId, operationId, 'deleteAuth', error); }
      return this.#recoverAfterCommit(() => this.#complete(ownerId, operationId, operation.type), ownerId, undefined, operationId);
    }
    throw deny('privacy_inconsistent_state');
  }

  async #claimExternal(ownerId, operationId, stage) {
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      update: (operation) => {
      const now = this.#now();
      const currentLease = operation.externalLease;
      const leaseIsActive = currentLease && currentLease.stage === stage &&
        now.getTime() - new Date(currentLease.claimedAt).getTime() <= EXTERNAL_LEASE_MS;
      if (operation.state !== 'authDeletionPending' || operation.authStage !== stage || (currentLease && leaseIsActive)) throw deny('privacy_operation_in_progress');
      operation.externalLease = { stage, claimedAt: now }; operation.updatedAt = now; operation.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  async #failExternal(ownerId, operationId, stage, error) {
    if (!(error instanceof PrivacyBackendFailure)) throw error;
    return this.#recoverAfterCommit(() => this.storage.updateOwned({
      ownerId,
      operationId,
      update: (operation) => {
      operation.state = 'failed'; operation.resumeState = 'authDeletionPending'; operation.authStage = stage;
      operation.externalLease = null; operation.updatedAt = this.#now(); operation.revision += 1;
      },
    }), ownerId, undefined, operationId);
  }

  async #complete(ownerId, operationId, type) {
    const completedAt = this.#now();
    const receipt = {
      receiptId: this.receiptIdGenerator.next(), type,
      result: type === 'financialReset' ? 'resetCompleted' : 'accountDeleted',
      completedAt, expiresAt: new Date(completedAt.getTime() + 30 * 24 * 60 * 60 * 1000),
    };
    return this.storage.complete({ ownerId, operationId, receipt });
  }

  async #ownedOperation(actor, operationId) {
    this.#assertActor(actor, actor?.uid);
    return this.storage.readOwned({ ownerId: actor.uid, operationId });
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
      const recovered = await this.storage.recover({ ownerId, requestFingerprint, operationId });
      if (recovered) return recovered;
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
