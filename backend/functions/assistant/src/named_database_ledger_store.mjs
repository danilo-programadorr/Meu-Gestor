/**
 * Responsabilidade: persiste somente o estado agregado e idempotente do ledger
 * no banco nomeado, autenticado por ADC da identidade runtime e sem Admin SDK.
 */
import { GoogleAuth } from 'google-auth-library';
import {
  AssistantReaderFailure,
  normalizeAssistantCostLedgerState,
} from '../shared/index.mjs';

const DATABASE_ID = 'assistant-controls-dev';
const DOCUMENT_PATH = 'assistantRuntime/ledger';
const MAX_TRANSACTION_ATTEMPTS = 3;
const clone = (value) => structuredClone(value);

const invalid = (diagnosticReason = 'unclassified') =>
  new AssistantReaderFailure('assistant_named_ledger_unavailable', diagnosticReason);
const isProjectId = (value) => typeof value === 'string' && /^[a-z][a-z0-9-]{4,62}$/u.test(value);
const isPlainRecord = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

// Traduz somente sinais técnicos fechados observados na própria transação; a
// mensagem e a pilha originais nunca são copiadas para a falha diagnóstica.
const transactionFailureReason = (error) => {
  if (error instanceof AssistantReaderFailure) return error.diagnosticReason;
  if (error?.response?.status === 401 || error?.response?.status === 403) return 'authorization_denied';
  if (error?.response?.status === 408 || error?.response?.status === 504
      || error?.name === 'AbortError' || error?.name === 'TimeoutError'
      || error?.code === 'ETIMEDOUT' || error?.code === 'UND_ERR_CONNECT_TIMEOUT') return 'timeout';
  if (['assistant_usage_limit_reached', 'assistant_pro_limit_reached',
    'assistant_cost_daily_limit_reached', 'assistant_cost_monthly_limit_reached'].includes(error?.code)) {
    return 'limit_exceeded';
  }
  if (error?.code === 'assistant_usage_record_required') return 'document_missing';
  if (['assistant_usage_record_invalid', 'assistant_cost_ledger_inconsistent'].includes(error?.code)) {
    return 'schema_invalid';
  }
  return 'unclassified';
};

const assertLedgerStateShape = (state) => {
  if (!isPlainRecord(state)
      || Object.keys(state).sort().join('|') !== 'daily|monthly|periods|records|usage'
      || !['daily', 'monthly', 'periods', 'records', 'usage'].every((key) => isPlainRecord(state[key]))) {
    throw invalid('schema_invalid');
  }
};

const databaseRoot = (projectId) => {
  if (!isProjectId(projectId) || projectId.includes('prod')) throw invalid();
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/${DATABASE_ID}`;
};

const decodeState = (document) => {
  if (document === null) throw invalid('document_missing');
  const raw = document?.fields?.state?.stringValue;
  if (typeof raw !== 'string' || raw.length === 0 || raw.length > 500_000) {
    throw invalid('schema_invalid');
  }
  try {
    const state = normalizeAssistantCostLedgerState(JSON.parse(raw));
    assertLedgerStateShape(state);
    return state;
  } catch {
    throw invalid('schema_invalid');
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
    if (!auth || typeof auth.getClient !== 'function' || typeof auth.getProjectId !== 'function') {
      throw invalid('adc_authentication_unavailable');
    }
    let client;
    let projectId;
    try {
      [client, projectId] = await Promise.all([auth.getClient(), auth.getProjectId()]);
    } catch (error) {
      const reason = transactionFailureReason(error);
      throw invalid(reason === 'unclassified' ? 'adc_authentication_unavailable' : reason);
    }
    if (!client || typeof client.request !== 'function') {
      throw invalid('adc_authentication_unavailable');
    }
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
        if (error instanceof AssistantReaderFailure) throw error;
        throw invalid(transactionFailureReason(error));
      }
    }
    throw invalid();
  }

  async #begin(client, root) {
    const response = await client.request({ method: 'POST', url: `${root}:beginTransaction`, data: {} });
    const transaction = response?.data?.transaction;
    if (typeof transaction !== 'string' || transaction.length < 8) {
      throw invalid('schema_invalid');
    }
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
      throw invalid('schema_invalid');
    }
  }
}

export const ASSISTANT_NAMED_LEDGER_DATABASE_ID = DATABASE_ID;
