/**
 * Responsabilidade: persiste somente o estado agregado e idempotente do ledger
 * no banco nomeado, autenticado por ADC da identidade runtime e sem Admin SDK.
 */
import { GoogleAuth } from 'google-auth-library';

const DATABASE_ID = 'assistant-controls-dev';
const DOCUMENT_PATH = 'assistantRuntime/ledger';
const MAX_TRANSACTION_ATTEMPTS = 3;
const emptyState = () => ({ daily: {}, monthly: {}, periods: {}, records: {} });
const clone = (value) => structuredClone(value);

const invalid = () => new Error('assistant_named_ledger_unavailable');
const isProjectId = (value) => typeof value === 'string' && /^[a-z][a-z0-9-]{4,62}$/u.test(value);
const isPlainRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

const assertLedgerStateShape = (state) => {
  if (!isPlainRecord(state)
      || Object.keys(state).sort().join('|') !== 'daily|monthly|periods|records'
      || !['daily', 'monthly', 'periods', 'records'].every((key) => isPlainRecord(state[key]))) {
    throw invalid();
  }
};

const databaseRoot = (projectId) => {
  if (!isProjectId(projectId) || projectId.includes('prod')) throw invalid();
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/${DATABASE_ID}`;
};

const decodeState = (document) => {
  if (document === null) return emptyState();
  const raw = document?.fields?.state?.stringValue;
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 500_000) throw invalid();
  try {
    const state = JSON.parse(raw);
    assertLedgerStateShape(state);
    return state;
  } catch {
    throw invalid();
  }
};

const documentWrite = ({ root, state, updateTime }) => {
  const update = {
    name: `${root}/documents/${DOCUMENT_PATH}`,
    fields: {
      schemaVersion: { integerValue: '1' },
      state: { stringValue: JSON.stringify(state) },
    },
  };
  return updateTime
    ? { update, currentDocument: { updateTime } }
    : { update, currentDocument: { exists: false } };
};

/**
 * Responsabilidade: adapta a transação REST do banco nomeado ao contrato
 * runTransaction do ledger, recusando banco, token ou resposta inesperados.
 */
export class NamedDatabaseAssistantCostLedgerStore {
  constructor({ authFactory = () => new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/datastore'] }) } = {}) {
    if (typeof authFactory !== 'function') throw new TypeError('assistant_named_ledger_auth_factory_invalid');
    this.authFactory = authFactory;
  }

  async runTransaction(callback) {
    if (typeof callback !== 'function') throw new TypeError('assistant_named_ledger_callback_invalid');
    const auth = this.authFactory();
    if (!auth || typeof auth.getClient !== 'function' || typeof auth.getProjectId !== 'function') throw invalid();
    let client;
    let projectId;
    try {
      [client, projectId] = await Promise.all([auth.getClient(), auth.getProjectId()]);
    } catch {
      throw invalid();
    }
    if (!client || typeof client.request !== 'function') throw invalid();
    const root = databaseRoot(projectId);

    for (let attempt = 0; attempt < MAX_TRANSACTION_ATTEMPTS; attempt += 1) {
      try {
        const transaction = await this.#begin(client, root);
        const document = await this.#read(client, root, transaction);
        const draft = clone(decodeState(document));
        const result = await callback(draft);
        assertLedgerStateShape(draft);
        await this.#commit(client, root, transaction, draft, document?.updateTime);
        return clone(result);
      } catch (error) {
        if (attempt + 1 < MAX_TRANSACTION_ATTEMPTS && error?.response?.status === 409) continue;
        throw invalid();
      }
    }
    throw invalid();
  }

  async #begin(client, root) {
    const response = await client.request({ method: 'POST', url: `${root}:beginTransaction`, data: {} });
    const transaction = response?.data?.transaction;
    if (typeof transaction !== 'string' || transaction.length < 8) throw invalid();
    return transaction;
  }

  async #read(client, root, transaction) {
    try {
      const response = await client.request({
        method: 'GET',
        url: `${root}/documents/${DOCUMENT_PATH}?transaction=${encodeURIComponent(transaction)}`,
      });
      return response?.data ?? null;
    } catch (error) {
      if (error?.response?.status === 404) return null;
      throw error;
    }
  }

  async #commit(client, root, transaction, state, updateTime) {
    const response = await client.request({
      method: 'POST',
      url: `${root}:commit`,
      data: { transaction, writes: [documentWrite({ root, state, updateTime })] },
    });
    if (!response?.data || !Array.isArray(response.data.writeResults) || response.data.writeResults.length !== 1) {
      throw invalid();
    }
  }
}

export const ASSISTANT_NAMED_LEDGER_DATABASE_ID = DATABASE_ID;
