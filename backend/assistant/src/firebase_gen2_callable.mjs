import { AssistantContractError, deny } from './errors.mjs';
import {
  ASSISTANT_FLUTTER_CONTRACT_VERSION,
  ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  prepareAssistantRemoteActivation,
  validateFlutterAssistantRequest,
} from './remote_activation_contract.mjs';
import { ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED } from './dual_model_execution.mjs';
import { AssistantModelRouter } from './model_router.mjs';
import { assertAuthorized } from './policy.mjs';

export const ASSISTANT_REMOTE_CALLABLE_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  memory: '256MiB',
  timeoutSeconds: 30,
  minInstances: 0,
  maxInstances: 1,
  concurrency: 1,
  enforceAppCheck: true,
});

export const ASSISTANT_SAFE_UNAVAILABLE = Object.freeze({
  status: 'safe_unavailable',
  contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
});

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

/**
 * Local-only Gen 2 callable factory. It receives platform primitives by
 * injection, so this checkpoint creates no deployed Function or Firebase
 * client. The provider flag and kill switch are deliberately fixed closed.
 */
export function createAssistRemoteV1Callables({
  onCall,
  HttpsError,
  authorizationReader,
  contextReader,
  usageReader,
  ledger,
  modelRouter = new AssistantModelRouter(),
  functionOptions = ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  killSwitchActive = ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  providerFeatureEnabled = ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
}) {
  if (
    typeof onCall !== 'function' || typeof HttpsError !== 'function'
    || typeof authorizationReader !== 'function' || typeof contextReader !== 'function'
    || typeof usageReader !== 'function' || !modelRouter || typeof modelRouter.route !== 'function'
  ) {
    throw new TypeError('assistant_callable_dependencies_invalid');
  }
  assertLedgerPort(ledger);
  if (killSwitchActive !== true || providerFeatureEnabled !== false) {
    throw new TypeError('assistant_callable_must_start_fail_closed');
  }
  if (!functionOptions || typeof functionOptions !== 'object' || Array.isArray(functionOptions)) {
    throw new TypeError('assistant_callable_options_invalid');
  }

  return Object.freeze({
    assistRemoteV1: onCall(functionOptions, async (request) => {
      try {
        const uid = requireAuthenticatedUid(request, HttpsError);
        requireExactFlutterData(request?.data, HttpsError);
        // Nenhuma leitura de perfil, contexto, ledger ou banco é permitida
        // enquanto a borda está desligada. Auth e App Check já passaram pelo
        // perímetro e a resposta não contém conteúdo do solicitante.
        if (killSwitchActive && !providerFeatureEnabled) {
          return ASSISTANT_SAFE_UNAVAILABLE;
        }
        const authorization = await deriveServerAuthorization({ request, uid, authorizationReader, HttpsError });
        assertAuthorized(authorization);
        if (authorization.financialPrivacyActive === true) {
          throw deny('assistant_financial_privacy_active');
        }

        validateFlutterAssistantRequest(request.data);
        const [context, usage] = await Promise.all([
          contextReader({ uid }),
          usageReader({ uid }),
        ]);
        // The port is intentionally not called while the provider is disabled.
        // Its strict shape prevents a later activation from bypassing the ledger.
        const plan = prepareAssistantRemoteActivation({
          flutterRequest: request.data,
          authorization,
          context,
          usage,
          modelRouter,
          killSwitchActive,
        });
        if (plan.allowed || providerFeatureEnabled || !killSwitchActive) {
          throw deny('assistant_callable_must_start_fail_closed');
        }
        return ASSISTANT_SAFE_UNAVAILABLE;
      } catch (error) {
        throw toHttpsError(error, HttpsError);
      }
    }),
  });
}

function assertLedgerPort(ledger) {
  if (!ledger || typeof ledger.reserve !== 'function' || typeof ledger.confirm !== 'function') {
    throw new TypeError('assistant_cost_ledger_port_invalid');
  }
}

function requireAuthenticatedUid(request, HttpsError) {
  const uid = request?.auth?.uid;
  if (typeof uid !== 'string' || uid.trim() !== uid || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Autenticação obrigatória.');
  }
  if (request.auth.token?.email_verified !== true) {
    throw new HttpsError('permission-denied', 'E-mail verificado obrigatório.');
  }
  if (request.app === null || request.app === undefined) {
    throw new HttpsError('failed-precondition', 'App Check obrigatório.');
  }
  return uid;
}

function requireExactFlutterData(data, HttpsError) {
  if (!exactKeys(data, ['contractVersion', 'message'])) {
    throw new HttpsError('invalid-argument', 'Contrato de chamada inválido.');
  }
}

async function deriveServerAuthorization({ request, uid, authorizationReader, HttpsError }) {
  const serverAuthorization = await authorizationReader({ uid });
  if (serverAuthorization === null || typeof serverAuthorization !== 'object' || Array.isArray(serverAuthorization)) {
    throw new HttpsError('failed-precondition', 'Autorização do servidor indisponível.');
  }
  // Auth, e-mail, App Check, UID e owner derivam exclusivamente do perímetro.
  return Object.freeze({
    ...serverAuthorization,
    authenticated: true,
    uid,
    requestedOwnerId: uid,
    emailVerified: request.auth.token.email_verified === true,
    appCheckVerified: request.app !== null && request.app !== undefined,
  });
}

function toHttpsError(error, HttpsError) {
  if (error instanceof HttpsError) return error;
  const code = error instanceof AssistantContractError ? error.code : null;
  if (code === 'assistant_unauthenticated') {
    return new HttpsError('unauthenticated', 'Autenticação obrigatória.');
  }
  if (code === 'assistant_invalid_request' || code === 'assistant_unsafe_content') {
    return new HttpsError('invalid-argument', 'Mensagem inválida.');
  }
  if (code === 'assistant_usage_limit_reached' || code === 'assistant_pro_limit_reached') {
    return new HttpsError('resource-exhausted', 'Limite de uso indisponível.');
  }
  if (code === 'assistant_financial_privacy_active') {
    return new HttpsError('failed-precondition', 'Privacidade financeira ativa.');
  }
  if (
    code === 'assistant_email_not_verified' || code === 'assistant_legal_profile_required'
    || code === 'assistant_consent_required' || code === 'assistant_consent_version_outdated'
  ) {
    return new HttpsError('permission-denied', 'Autorização obrigatória.');
  }
  return new HttpsError('failed-precondition', 'Assistente indisponível com segurança.');
}
