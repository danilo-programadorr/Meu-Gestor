/**
 * Responsabilidade: compõe o ledger de custo da callable com ADC e banco
 * nomeado, sem conceder acesso ao banco financeiro padrão.
 */
import { AssistantCostControlLedger } from '../shared/index.mjs';
import { NamedDatabaseAssistantCostLedgerStore } from './named_database_ledger_store.mjs';

/**
 * Responsabilidade: cria a porta transacional que só será acionada depois dos
 * controles de runtime, autorização e privacidade aprovarem a requisição.
 */
export const createAssistantRuntimeLedger = ({
  clock = () => new Date(),
  store = new NamedDatabaseAssistantCostLedgerStore(),
} = {}) => new AssistantCostControlLedger({ clock, store });
