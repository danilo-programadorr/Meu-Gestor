import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { registerAssistRemoteV1Gen2 } from './shared/firebase_gen2_registration.mjs';
import { createFailClosedAssistantDependencies } from './src/fail_closed_dependencies.mjs';
import { ASSISTANT_FUNCTION_OPTIONS } from './src/function_options.mjs';

// Não importa Firebase Admin nem cliente Firestore: este codebase não pode
// acessar o banco (default), coleções financeiras ou o banco de controles.
const dependencies = createFailClosedAssistantDependencies({ HttpsError });
const callables = registerAssistRemoteV1Gen2({
  onCall,
  HttpsError,
  functionOptions: ASSISTANT_FUNCTION_OPTIONS,
  ...dependencies,
});

export const assistRemoteV1 = callables.assistRemoteV1;
