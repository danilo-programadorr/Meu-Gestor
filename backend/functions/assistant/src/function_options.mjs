/**
 * Responsabilidade: centraliza limites Gen 2 e parâmetros sem valores
 * versionados, preservando o circuito fechado por padrão.
 */
import { defineBoolean, defineString } from 'firebase-functions/params';

// O valor existe apenas no ambiente de deploy autorizado. Sem esse parâmetro,
// a CLI não pode materializar a configuração da Function.
export const assistantRuntimeServiceAccount = defineString('ASSISTANT_RUNTIME_SERVICE_ACCOUNT');
export const assistantProviderFeatureEnabled = defineBoolean('ASSISTANT_REAL_PROVIDER_ENABLED');

// firebase-functions 7.3.2 resolve parâmetros booleanos ausentes como false.
// Logo, o único modo de desligar o circuito é declarar explicitamente a
// sinalização inversa no ambiente autorizado; a ausência mantém o bloqueio.
const assistantKillSwitchDisabled = defineBoolean('ASSISTANT_KILL_SWITCH_DISABLED');
export const assistantKillSwitchActive = Object.freeze({
  value: () => !assistantKillSwitchDisabled.value(),
});

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
