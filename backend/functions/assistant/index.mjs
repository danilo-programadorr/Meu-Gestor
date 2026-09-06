/**
 * Responsabilidade: expõe somente a callable Gen 2 do Assistente com limites
 * conservadores e composição fail-closed no codebase isolado.
 */
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  createVertexRuntimeGateway,
  registerAssistRemoteV1Gen2,
} from './shared/index.mjs';
import { createFailClosedAssistantDependencies } from './src/fail_closed_dependencies.mjs';
import {
  ASSISTANT_FUNCTION_OPTIONS,
  assistantKillSwitchActive,
  assistantProviderFeatureEnabled,
} from './src/function_options.mjs';

// Não importa Firebase Admin nem cliente Firestore: este codebase não pode
// acessar o banco (default), coleções financeiras ou o banco de controles.
// Os controles são resolvidos no runtime da Function; nunca pelo Flutter.
const killSwitchActive = assistantKillSwitchActive.value();
const providerFeatureEnabled = assistantProviderFeatureEnabled.value();
const providerGateway = createVertexRuntimeGateway({
  killSwitchActive,
  providerFeatureEnabled,
});
const dependencies = createFailClosedAssistantDependencies({ HttpsError, providerGateway });
const callables = registerAssistRemoteV1Gen2({
  onCall,
  HttpsError,
  functionOptions: ASSISTANT_FUNCTION_OPTIONS,
  killSwitchActive,
  providerFeatureEnabled,
  ...dependencies,
});

export const assistRemoteV1 = callables.assistRemoteV1;
