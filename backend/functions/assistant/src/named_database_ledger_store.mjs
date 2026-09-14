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
const httpStatus = (value) => {
  const status = value?.response?.status ?? value?.status;
  return Number.isInteger(status) && status >= 100 && status <= 599 ? status : undefined;
};

// Traduz somente sinais técnicos fechados observados na própria transação; a
// mensagem e a pilha originais nunca são copiadas para a falha diagnóstica.
const transactionFailureReason = (error) => {
  if (error instanceof AssistantReaderFailure) return error.diagnosticReason;
  const status = httpStatus(error);
  if (status === 401 || status === 403) return 'authorization_denied';
  if (status === 429) return 'limit_exceeded';
  if (status === 408 || status === 504
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
  constructor({
    authFactory = () => new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/datastore'] }),
    runtimeDiagnostics = undefined,
  } = {}) {
    if (typeof authFactory !== 'function') throw new TypeError('assistant_named_ledger_auth_factory_invalid');
    if (runtimeDiagnostics !== undefined
        && (!runtimeDiagnostics || typeof runtimeDiagnostics.report !== 'function')) {
      throw new TypeError('assistant_named_ledger_diagnostics_invalid');
    }
    this.authFactory = authFactory;
    this.runtimeDiagnostics = runtimeDiagnostics ?? null;
  }

  async runTransaction(callback) {
    if (typeof callback !== 'function') throw new TypeError('assistant_named_ledger_callback_invalid');
    // A obtenção ADC é observada separadamente das chamadas Firestore e nunca
    // inclui credencial, identidade, projeto ou mensagem de erro no evento.
    this.#report('usage_adc_credentials', 'started');
    let auth;
    let client;
    let projectId;
    try {
      auth = this.authFactory();
      if (!auth || typeof auth.getClient !== 'function' || typeof auth.getProjectId !== 'function') {
        throw invalid('adc_authentication_unavailable');
      }
      [client, projectId] = await Promise.all([auth.getClient(), auth.getProjectId()]);
      if (!client || typeof client.request !== 'function') {
        throw invalid('adc_authentication_unavailable');
      }
    } catch (error) {
      const reason = transactionFailureReason(error);
      const adcReason = reason === 'unclassified' ? 'adc_authentication_unavailable' : reason;
      this.#report('usage_adc_credentials', 'failed', { reason: adcReason, httpStatus: httpStatus(error) });
      if (error instanceof AssistantReaderFailure && error.diagnosticReason === adcReason) throw error;
      throw invalid(adcReason);
    }
    this.#report('usage_adc_credentials', 'passed');
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
    const response = await this.#request(client, 'usage_firestore_begin_transaction', {
      method: 'POST', url: `${root}/documents:beginTransaction`, data: {},
    });
    const transaction = response?.data?.transaction;
    if (typeof transaction !== 'string' || transaction.length < 8) {
      throw invalid('schema_invalid');
    }
    return transaction;
  }

  async #read(client, root, transaction) {
    try {
      const response = await this.#request(client, 'usage_firestore_read', {
        method: 'GET',
        url: `${root}/documents/${DOCUMENT_PATH}?transaction=${encodeURIComponent(transaction)}`,
      }, (error) => httpStatus(error) === 404 ? 'document_missing' : transactionFailureReason(error));
      return response?.data ?? null;
    } catch (error) {
      if (error?.response?.status === 404) return null;
      throw error;
    }
  }

  async #commit(client, root, transaction, state, updateTime) {
    const response = await this.#request(client, 'usage_firestore_commit', {
      method: 'POST',
      url: `${root}/documents:commit`,
      data: { transaction, writes: [documentWrite({ root, state, updateTime })] },
    });
    if (!response?.data || !Array.isArray(response.data.writeResults) || response.data.writeResults.length !== 1) {
      throw invalid('schema_invalid');
    }
  }

  // O wrapper registra somente enums e status numérico; resposta, requisição,
  // URL, transação e erro bruto permanecem exclusivamente no transporte.
  async #request(client, stage, request, failureReason = transactionFailureReason) {
    this.#report(stage, 'started');
    try {
      const response = await client.request(request);
      this.#report(stage, 'passed', { httpStatus: httpStatus(response) });
      return response;
    } catch (error) {
      this.#report(stage, 'failed', {
        reason: failureReason(error),
        httpStatus: httpStatus(error),
      });
      throw error;
    }
  }

  #report(stage, outcome, { reason = undefined, httpStatus: status = undefined } = {}) {
    if (this.runtimeDiagnostics === null) return;
    const event = { stage, outcome };
    if (reason !== undefined) event.reason = reason;
    if (status !== undefined) event.httpStatus = status;
    try {
      this.runtimeDiagnostics.report(event);
    } catch {
      // Observabilidade é best-effort e nunca altera a transação fail-closed.
    }
  }
}

export const ASSISTANT_NAMED_LEDGER_DATABASE_ID = DATABASE_ID;
