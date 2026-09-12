/**
 * Responsabilidade: lê a janela agregada do proprietário no banco nomeado.
 * O UID autenticado é usado somente em memória para derivar um escopo opaco.
 */
import { createAssistantOwnerScope } from '../shared/index.mjs';

export const createAssistantRuntimeUsageReader = ({ ledger } = {}) => {
  if (!ledger || typeof ledger.readUsage !== 'function') {
    throw new TypeError('assistant_runtime_usage_ledger_invalid');
  }
  return async ({ uid } = {}) => ledger.readUsage({
    ownerScope: createAssistantOwnerScope(uid),
  });
};
