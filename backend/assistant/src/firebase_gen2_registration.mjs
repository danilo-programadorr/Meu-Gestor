/**
 * Responsabilidade: registra somente a composição Gen 2 permitida, sem criar
 * recurso em nuvem nem aceitar configuração sensível do cliente.
 */
import {
  ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  createAssistRemoteV1Callables,
} from './firebase_gen2_callable.mjs';

// This is the stable export name for a future Functions Gen 2 codebase.
// The current checkpoint keeps it as an injected local composition only.
export const ASSISTANT_REMOTE_FUNCTION_NAME = 'assistRemoteV1';

/**
 * Registers the local-safe callable with a supplied Gen 2 onCall factory.
 * No Firebase SDK, project configuration or network resource is created here.
 */
/**
 * Encaminha exclusivamente dependências validadas para a factory da callable.
 */
export function registerAssistRemoteV1Gen2({
  onCall,
  HttpsError,
  authorizationReader,
  contextReader,
  usageReader,
  ledger,
  providerGateway,
  modelRouter,
  functionOptions,
  killSwitchActive,
  providerFeatureEnabled,
  runtimeControlsReader,
  runtimeDiagnostics,
}) {
  const callables = createAssistRemoteV1Callables({
    onCall,
    HttpsError,
    authorizationReader,
    contextReader,
    usageReader,
    ledger,
    providerGateway,
    ...(modelRouter ? { modelRouter } : {}),
    ...(functionOptions ? { functionOptions } : {}),
    ...(typeof killSwitchActive === 'boolean' ? { killSwitchActive } : {}),
    ...(typeof providerFeatureEnabled === 'boolean' ? { providerFeatureEnabled } : {}),
    ...(typeof runtimeControlsReader === 'function' ? { runtimeControlsReader } : {}),
    ...(runtimeDiagnostics ? { runtimeDiagnostics } : {}),
  });
  return Object.freeze({
    [ASSISTANT_REMOTE_FUNCTION_NAME]: callables.assistRemoteV1,
  });
}

export const getAssistRemoteV1Gen2Options = () => ASSISTANT_REMOTE_CALLABLE_OPTIONS;
