import { createHash } from 'node:crypto';

import { deny } from '../../../privacy/src/errors.mjs';

const LEDGER_PATH = 'assistantRuntime/ledger';

/// Remove somente chaves owner-scoped do ledger nomeado. Contadores globais
/// de custo permanecem agregados e nenhum valor de uso é copiado para logs ou
/// para o recibo da operação.
export function createAssistantUsagePrivacyTarget({ firestore }) {
  if (!firestore || typeof firestore.runTransaction !== 'function' || typeof firestore.doc !== 'function') {
    throw new TypeError('privacy_assistant_ledger_dependency_invalid');
  }
  return Object.freeze({
    deleteOwner: async ({ ownerId }) => {
      const ownerScope = assistantOwnerScope(ownerId);
      await firestore.runTransaction(async (transaction) => {
        const reference = firestore.doc(LEDGER_PATH);
        const snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;
        const state = structuredClone(snapshot.data());
        validateLedger(state);
        delete state.usage[ownerScope];
        for (const [requestId, record] of Object.entries(state.records)) {
          if (record?.ownerScope === ownerScope) {
            delete state.records[requestId];
            delete state.periods[requestId];
          }
        }
        if (Object.keys(state.records).sort().join('|') !== Object.keys(state.periods).sort().join('|')) {
          throw deny('privacy_assistant_ledger_inconsistent');
        }
        transaction.set(reference, state);
      });
    },
  });
}

export function assistantOwnerScope(ownerId) {
  if (typeof ownerId !== 'string' || ownerId.trim() !== ownerId ||
      ownerId.length < 1 || ownerId.length > 128) {
    throw deny('privacy_invalid_request');
  }
  return createHash('sha256')
    .update(`assistant-owner-usage-v1:${ownerId}`, 'utf8')
    .digest('hex');
}

function validateLedger(state) {
  if (!isRecord(state) || Object.keys(state).sort().join('|') !== 'daily|monthly|periods|records|usage' ||
      !['daily', 'monthly', 'periods', 'records', 'usage'].every((field) => isRecord(state[field]))) {
    throw deny('privacy_assistant_ledger_inconsistent');
  }
  for (const [requestId, record] of Object.entries(state.records)) {
    if (!isRecord(record) || typeof record.ownerScope !== 'string' || !Object.hasOwn(state.periods, requestId)) {
      throw deny('privacy_assistant_ledger_inconsistent');
    }
  }
}

const isRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
