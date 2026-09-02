import { defineString } from 'firebase-functions/params';

// O valor existe apenas no ambiente de deploy autorizado. Sem esse parâmetro,
// a CLI não pode materializar a configuração da Function.
export const assistantRuntimeServiceAccount = defineString('ASSISTANT_RUNTIME_SERVICE_ACCOUNT');

export const ASSISTANT_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: assistantRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  enforceAppCheck: true,
});
