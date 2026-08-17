import { deny } from './errors.mjs';
import { SubscriptionTransactionalStorage } from './storage.mjs';

/// Adaptador preparado para o Admin SDK futuro. As funções de leitura/escrita
/// são injetadas para manter esta camada executável com fakes e sem importar
/// Firebase, credencial, Project ID ou serviço externo nesta etapa.
export class FirestoreSubscriptionTransactionalStorage extends SubscriptionTransactionalStorage {
  constructor({ runTransaction, readState, writeState, readSnapshot, readEntitlement }) {
    super();
    for (const value of [runTransaction, readState, writeState, readSnapshot, readEntitlement]) {
      if (typeof value !== 'function') throw deny('invalid_firestore_storage_adapter');
    }
    this.runTransaction = runTransaction;
    this.readState = readState;
    this.writeState = writeState;
    this.readSnapshot = readSnapshot;
    this.readEntitlement = readEntitlement;
  }

  async transaction(operation) {
    if (typeof operation !== 'function') throw deny('invalid_subscription_transaction');
    return this.runTransaction(async (transaction) => {
      const state = await this.readState(transaction);
      const result = await operation(state);
      await this.writeState(transaction, state);
      return structuredClone(result);
    });
  }

  async snapshot() {
    return structuredClone(await this.readSnapshot());
  }

  async entitlement(ownerId) {
    return structuredClone(await this.readEntitlement(ownerId));
  }
}
