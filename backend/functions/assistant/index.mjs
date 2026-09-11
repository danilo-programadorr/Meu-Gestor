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
import { createAssistantRuntimeLedger } from './src/runtime_ledger.mjs';
import { createAssistantRuntimeAdapters } from './src/runtime_adapters.mjs';
import {
  ASSISTANT_FUNCTION_OPTIONS,
  readAssistantRuntimeControls,
} from './src/function_options.mjs';

// Não importa Firebase Admin nem cliente Firestore: este codebase não pode
// acessar o banco (default), coleções financeiras ou o banco de controles.
// Os controles são resolvidos no runtime da Function; nunca pelo Flutter.
const providerGateway = createVertexRuntimeGateway({
  runtimeControlsReader: readAssistantRuntimeControls,
});
const runtimeAdapters = createAssistantRuntimeAdapters();
const dependencies = createFailClosedAssistantDependencies({
  HttpsError,
  providerGateway,
  ledger: createAssistantRuntimeLedger(),
  ...runtimeAdapters,
});
const callables = registerAssistRemoteV1Gen2({
  onCall,
  HttpsError,
  functionOptions: ASSISTANT_FUNCTION_OPTIONS,
  runtimeControlsReader: readAssistantRuntimeControls,
  ...dependencies,
});

export const assistRemoteV1 = callables.assistRemoteV1;
