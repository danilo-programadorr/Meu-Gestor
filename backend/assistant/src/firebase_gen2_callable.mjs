/**
 * Responsabilidade: orquestra a callable segura do Assistente, validando o
 * perímetro e mantendo o fluxo remoto bloqueado até uma ativação autorizada.
 */
import { AssistantContractError, deny } from './errors.mjs';
import {
  ASSISTANT_FLUTTER_CONTRACT_VERSION,
  ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  prepareAssistantRemoteActivation,
  sanitizedAssistantActivationFailureCode,
  validateFlutterAssistantRequest,
} from './remote_activation_contract.mjs';
import {
  ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
  resolveAssistantModelExecution,
} from './dual_model_execution.mjs';
import { AssistantModelRouter } from './model_router.mjs';
import { assertAuthorized } from './policy.mjs';
import {
  admitAssistantClarificationPlan,
  admitGroundedAssistantResponse,
} from './grounded_response_contract.mjs';
import { createAssistantCostRequestId, createAssistantOwnerScope } from './cost_control_ledger.mjs';
import { createOwnerScopedFirestoreAuthority } from './owner_scoped_firestore_context.mjs';
import { assistantReaderFailureReason } from './reader_failure_diagnostics.mjs';
import { buildAuthoritativeAssetListResponse } from './authoritative_financial_response.mjs';

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

export const ASSISTANT_MAXIMUM_VERTEX_COST_CENTS = Object.freeze({
  flash: 20,
  pro: 100,
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
/**
 * Compõe a callable com portas injetadas para que domínio e testes não
 * dependam de Firebase, banco ou provedor externos.
 */
export function createAssistRemoteV1Callables({
  onCall,
  HttpsError,
  authorizationReader,
  contextReader,
  usageReader,
  ledger,
  providerGateway,
  modelRouter = new AssistantModelRouter(),
  functionOptions = ASSISTANT_REMOTE_CALLABLE_OPTIONS,
  killSwitchActive = ASSISTANT_REMOTE_KILL_SWITCH_ACTIVE,
  providerFeatureEnabled = ASSISTANT_REAL_PROVIDER_FEATURE_ENABLED,
  runtimeControlsReader = () => Object.freeze({ killSwitchActive, providerFeatureEnabled }),
  runtimeDiagnostics = undefined,
}) {
  if (
    typeof onCall !== 'function' || typeof HttpsError !== 'function'
    || typeof authorizationReader !== 'function' || typeof contextReader !== 'function'
    || typeof usageReader !== 'function' || !modelRouter || typeof modelRouter.route !== 'function'
  ) {
    throw new TypeError('assistant_callable_dependencies_invalid');
  }
  assertLedgerPort(ledger);
  assertProviderGateway(providerGateway);
  if (typeof killSwitchActive !== 'boolean' || typeof providerFeatureEnabled !== 'boolean' || typeof runtimeControlsReader !== 'function') {
    throw new TypeError('assistant_callable_controls_invalid');
  }
  if (!functionOptions || typeof functionOptions !== 'object' || Array.isArray(functionOptions)) {
    throw new TypeError('assistant_callable_options_invalid');
  }
  const diagnostics = normalizeRuntimeDiagnostics(runtimeDiagnostics);

  return Object.freeze({
    assistRemoteV1: onCall(functionOptions, async (request) => {
      let stage = 'auth_app_check';
      reportRuntimeStage(diagnostics, 'handler_entry', 'started');
      try {
        const uid = requireAuthenticatedUid(request, HttpsError);
        const ownerScope = createAssistantOwnerScope(uid);
        reportRuntimeStage(diagnostics, stage, 'passed');
        requireExactFlutterData(request?.data, HttpsError);
        stage = 'runtime_controls';
        reportRuntimeStage(diagnostics, stage, 'started');
        const runtimeControls = readRuntimeControls(runtimeControlsReader);
        const { killSwitchActive: runtimeKillSwitchActive, providerFeatureEnabled: runtimeProviderFeatureEnabled } = runtimeControls;
        // Nenhuma leitura de perfil, contexto, ledger ou banco é permitida
        // enquanto a borda está desligada. Auth e App Check já passaram pelo
        // perímetro e a resposta não contém conteúdo do solicitante.
        if (runtimeKillSwitchActive || !runtimeProviderFeatureEnabled) {
          reportRuntimeStage(diagnostics, stage, 'blocked');
          return ASSISTANT_SAFE_UNAVAILABLE;
        }
        reportRuntimeStage(diagnostics, stage, 'passed');
        const ownerAuthority = createOwnerScopedFirestoreAuthority({
          uid,
          authorizationHeader: request?.rawRequest?.headers?.authorization,
        });
        stage = 'authorization_consent';
        reportRuntimeStage(diagnostics, stage, 'started');
        const authorization = await deriveServerAuthorization({ request, uid, ownerAuthority, authorizationReader, HttpsError });
        assertAuthorized(authorization);
        if (authorization.financialPrivacyActive === true) {
          reportRuntimeStage(diagnostics, stage, 'blocked');
          throw deny('assistant_financial_privacy_active');
        }
        reportRuntimeStage(diagnostics, stage, 'passed');

        const validatedFlutterRequest = validateFlutterAssistantRequest(request.data);
        // A voz neural é produzida somente depois da admissão do texto. Assim,
        // áudio nunca contorna evidências e o modo texto não paga essa chamada.
        const finalizeForResponseMode = async ({ response, text }) => {
          if (validatedFlutterRequest.responseMode !== 'voice') return response;
          if (typeof providerGateway.synthesize !== 'function') {
            throw deny('assistant_provider_configuration_unavailable');
          }
          const speechRequestId = createAssistantCostRequestId();
          stage = 'voice_ledger_reserve';
          reportRuntimeStage(diagnostics, stage, 'started');
          await ledger.reserve({
            maximumCostCents: ASSISTANT_MAXIMUM_VERTEX_COST_CENTS.flash,
            ownerScope,
            requestId: speechRequestId,
            tier: 'flash',
            usageCostUnits: 1,
          });
          reportRuntimeStage(diagnostics, stage, 'passed');
          stage = 'voice_model';
          reportRuntimeStage(diagnostics, stage, 'started');
          const speechResult = await providerGateway.synthesize({
            maximumCostCents: ASSISTANT_MAXIMUM_VERTEX_COST_CENTS.flash,
            text,
          });
          reportRuntimeStage(diagnostics, stage, 'passed');
          stage = 'voice_ledger_confirm';
          reportRuntimeStage(diagnostics, stage, 'started');
          await ledger.confirm({
            requestId: speechRequestId,
            durationMs: speechResult.durationMs,
            confirmedCostCents: speechResult.confirmedCostCents,
          });
          reportRuntimeStage(diagnostics, stage, 'passed');
          return Object.freeze({ ...response, audio: speechResult.audio });
        };
        // O primeiro passe interpreta intenção e período sem receber fatos. A
        // quota é reservada antes da inferência e confirmada mesmo quando o
        // resultado pede esclarecimento ou falha fechado.
        stage = 'intent_usage_reader';
        const intentUsage = await traceRuntimeReader({
          diagnostics,
          stage,
          read: () => usageReader({ uid }),
        });
        stage = 'intent_activation_plan';
        reportRuntimeStage(diagnostics, stage, 'started');
        const planningRouting = modelRouter.route({
          message: 'intent plan',
          context: Object.freeze({ facts: Object.freeze([]), missingSources: Object.freeze([]) }),
          usage: intentUsage,
        });
        const planningExecution = resolveAssistantModelExecution({
          routing: Object.freeze({ tier: planningRouting.tier }),
          featureEnabled: runtimeProviderFeatureEnabled,
        });
        reportRuntimeStage(diagnostics, stage, 'passed');
        const planningRequestId = createAssistantCostRequestId();
        stage = 'intent_ledger_reserve';
        reportRuntimeStage(diagnostics, stage, 'started');
        await ledger.reserve({
          maximumCostCents: ASSISTANT_MAXIMUM_VERTEX_COST_CENTS.flash,
          ownerScope,
          requestId: planningRequestId,
          tier: 'flash',
          usageCostUnits: planningRouting.costUnits,
        });
        reportRuntimeStage(diagnostics, stage, 'passed');
        stage = 'intent_model';
        reportRuntimeStage(diagnostics, stage, 'started');
        const intentResult = await providerGateway.plan({
          execution: Object.freeze({
            ...planningExecution,
            tier: 'flash',
            thinkingLevel: 'LOW',
          }),
          maximumCostCents: ASSISTANT_MAXIMUM_VERTEX_COST_CENTS.flash,
          request: Object.freeze({
            message: validatedFlutterRequest.message,
            ...(validatedFlutterRequest.continuation
              ? { continuation: validatedFlutterRequest.continuation }
              : {}),
          }),
        });
        reportRuntimeStage(diagnostics, stage, 'passed', intentResult.providerDiagnostics);
        stage = 'intent_ledger_confirm';
        reportRuntimeStage(diagnostics, stage, 'started');
        await ledger.confirm({
          requestId: planningRequestId,
          durationMs: intentResult.durationMs,
          confirmedCostCents: intentResult.confirmedCostCents,
        });
        reportRuntimeStage(diagnostics, stage, 'passed');
        if (intentResult.plan === null) {
          reportRuntimeStage(diagnostics, 'response_validation', 'passed', {
            finalStatus: 'safe_unavailable',
            reason: intentResult.providerOutputIssue ?? 'provider_reported_insufficient_evidence',
          });
          return ASSISTANT_SAFE_UNAVAILABLE;
        }
        // Uma intenção não resolvida é uma conversa incompleta, não uma falha
        // técnica. O servidor pede contexto sem tocar dados financeiros.
        if (intentResult.plan.status === 'safe_unavailable') {
          const clarification = admitAssistantClarificationPlan({
            intent: 'unknown',
            clarificationCode: 'intent_ambiguous',
          });
          reportRuntimeStage(diagnostics, 'response_validation', 'passed', {
            finalStatus: clarification.finalStatus,
          });
          return finalizeForResponseMode({
            response: clarification.response,
            text: clarification.response.question,
          });
        }
        if (intentResult.plan.status === 'clarification_required') {
          const clarification = admitAssistantClarificationPlan(intentResult.plan);
          reportRuntimeStage(diagnostics, 'response_validation', 'passed', {
            finalStatus: clarification.finalStatus,
          });
          return finalizeForResponseMode({
            response: clarification.response,
            text: clarification.response.question,
          });
        }
        // A autorização crua vem somente do envelope já validado pela callable.
        // Ela é efêmera, serve à leitura própria nas Rules e nunca chega ao modelo.
        stage = 'owner_scoped_context_and_usage';
        reportRuntimeStage(diagnostics, stage, 'started');
        // Cada leitor preserva sua execução paralela e relata apenas enums
        // sanitizados. Em falha, ambos são aguardados antes de relançar a
        // primeira exceção, sem permitir avanço parcial ao ledger ou Vertex.
        const contextOperation = traceRuntimeReader({
          diagnostics,
          stage: 'owner_scoped_context',
          read: () => contextReader({
            uid,
            ownerAuthority,
            authorization,
            periodCode: intentResult.plan.periodCode,
            financialTool: intentResult.plan.financialTool,
          }),
        });
        const usageOperation = traceRuntimeReader({
          diagnostics,
          stage: 'usage_reader',
          read: () => usageReader({ uid }),
        });
        let context;
        let usage;
        try {
          [context, usage] = await Promise.all([contextOperation, usageOperation]);
        } catch (readerError) {
          await Promise.allSettled([contextOperation, usageOperation]);
          throw readerError;
        }
        reportRuntimeStage(diagnostics, stage, 'passed');
        // Consultas explícitas de nomes/tickers não precisam de uma segunda
        // inferência: o servidor renderiza somente os rótulos owner-scoped.
        const authoritativeResponse = intentResult.plan.intent === 'investment_assets'
          ? buildAuthoritativeAssetListResponse(context)
          : null;
        if (authoritativeResponse !== null) {
          stage = 'authoritative_response';
          reportRuntimeStage(diagnostics, stage, 'started');
          const admission = admitGroundedAssistantResponse({
            response: authoritativeResponse,
            context,
          });
          reportRuntimeStage(
            diagnostics,
            stage,
            'passed',
            admission.finalStatus === 'grounded'
              ? { finalStatus: admission.finalStatus }
              : { finalStatus: admission.finalStatus, reason: admission.reason },
          );
          return admission.finalStatus === 'grounded'
            ? finalizeForResponseMode({
                response: admission.response,
                text: admission.response.answer,
              })
            : ASSISTANT_SAFE_UNAVAILABLE;
        }
        // The port is intentionally not called while the provider is disabled.
        // Its strict shape prevents a later activation from bypassing the ledger.
        stage = 'activation_plan';
        reportRuntimeStage(diagnostics, stage, 'started');
        const plan = prepareAssistantRemoteActivation({
          flutterRequest: request.data,
          authorization,
          context,
          usage,
          modelRouter,
          killSwitchActive: runtimeKillSwitchActive,
          providerFeatureEnabled: runtimeProviderFeatureEnabled,
        });
        if (!plan.allowed) {
          reportRuntimeStage(diagnostics, stage, 'blocked');
          return ASSISTANT_SAFE_UNAVAILABLE;
        }
        reportRuntimeStage(diagnostics, stage, 'passed');
        const execution = resolveAssistantModelExecution({
          routing: Object.freeze({ tier: plan.tier }),
          featureEnabled: runtimeProviderFeatureEnabled,
        });
        const maximumCostCents = ASSISTANT_MAXIMUM_VERTEX_COST_CENTS[execution.tier];
        const requestId = createAssistantCostRequestId();
        stage = 'ledger_reserve';
        reportRuntimeStage(diagnostics, stage, 'started');
        await ledger.reserve({
          maximumCostCents,
          ownerScope,
          requestId,
          tier: execution.tier,
          usageCostUnits: plan.costUnits,
        });
        reportRuntimeStage(diagnostics, stage, 'passed');
        stage = 'vertex_model';
        reportRuntimeStage(diagnostics, stage, 'started');
        const providerResult = await providerGateway.generate({
          execution,
          maximumCostCents,
          providerRequest: Object.freeze({
            contractVersion: ASSISTANT_FLUTTER_CONTRACT_VERSION,
            message: request.data.message,
            ...(request.data.continuation
              ? { continuation: request.data.continuation }
              : {}),
            intentPlan: intentResult.plan,
            context,
          }),
        });
        // O marcador conserva somente forma e término enumerados da resposta;
        // texto, contexto e mensagens do provedor nunca entram no diagnóstico.
        reportRuntimeStage(diagnostics, stage, 'passed', providerResult.providerDiagnostics);
        stage = 'ledger_confirm';
        reportRuntimeStage(diagnostics, stage, 'started');
        await ledger.confirm({
          requestId,
          durationMs: providerResult.durationMs,
          confirmedCostCents: providerResult.confirmedCostCents,
        });
        reportRuntimeStage(diagnostics, stage, 'passed');
        stage = 'response_validation';
        reportRuntimeStage(diagnostics, stage, 'started');
        const admission = admitGroundedAssistantResponse({
          response: providerResult.response,
          context,
          providerOutputIssue: providerResult.providerOutputIssue,
        });
        // O diagnóstico conserva somente status e motivo enumerados. O fallback
        // entregue ao Flutter permanece mínimo e nunca promove ausência de
        // evidência para uma resposta fundamentada.
        reportRuntimeStage(
          diagnostics,
          stage,
          'passed',
          ['grounded', 'clarification_required'].includes(admission.finalStatus)
            ? { finalStatus: admission.finalStatus }
            : { finalStatus: admission.finalStatus, reason: admission.reason },
        );
        return ['grounded', 'clarification_required'].includes(admission.finalStatus)
          ? finalizeForResponseMode({
              response: admission.response,
              text: admission.finalStatus === 'grounded'
                ? admission.response.answer
                : admission.response.question,
            })
          : ASSISTANT_SAFE_UNAVAILABLE;
      } catch (error) {
        reportRuntimeStage(
          diagnostics,
          stage,
          'failed',
          ['activation_plan', 'intent_activation_plan'].includes(stage)
            ? { code: sanitizedAssistantActivationFailureCode(error) }
            : undefined,
        );
        throw toHttpsError(error, HttpsError);
      }
    }),
  });
}

function normalizeRuntimeDiagnostics(runtimeDiagnostics) {
  if (runtimeDiagnostics === undefined) return null;
  if (!runtimeDiagnostics || typeof runtimeDiagnostics.report !== 'function') {
    throw new TypeError('assistant_callable_runtime_diagnostics_invalid');
  }
  return runtimeDiagnostics;
}

function reportRuntimeStage(diagnostics, stage, outcome, details = undefined) {
  if (diagnostics === null) return;
  // A porta recebe somente rótulos constantes; nunca request, erro, UID ou conteúdo.
  try {
    diagnostics.report(details === undefined ? { stage, outcome } : { stage, outcome, ...details });
  } catch {
    // Diagnóstico é observabilidade best-effort e não pode alterar o fail-closed.
  }
}

// Envolve exclusivamente o resultado técnico do leitor e sempre relança a
// mesma exceção; a classificação fechada é derivada do erro na origem.
async function traceRuntimeReader({ diagnostics, stage, read }) {
  reportRuntimeStage(diagnostics, stage, 'started');
  try {
    const result = await read();
    reportRuntimeStage(diagnostics, stage, 'passed');
    return result;
  } catch (error) {
    reportRuntimeStage(diagnostics, stage, 'failed', { reason: assistantReaderFailureReason(error) });
    throw error;
  }
}

function assertLedgerPort(ledger) {
  if (!ledger || typeof ledger.reserve !== 'function' || typeof ledger.confirm !== 'function') {
    throw new TypeError('assistant_cost_ledger_port_invalid');
  }
}

function assertProviderGateway(providerGateway) {
  if (!providerGateway
      || typeof providerGateway.plan !== 'function'
      || typeof providerGateway.generate !== 'function') {
    throw new TypeError('assistant_provider_gateway_port_invalid');
  }
}

function readRuntimeControls(runtimeControlsReader) {
  const controls = runtimeControlsReader();
  if (!controls || typeof controls !== 'object' || Array.isArray(controls)
      || typeof controls.killSwitchActive !== 'boolean'
      || typeof controls.providerFeatureEnabled !== 'boolean') {
    throw new TypeError('assistant_callable_runtime_controls_invalid');
  }
  return controls;
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
  const hasContinuation = Object.hasOwn(data ?? {}, 'continuation');
  const hasResponseMode = Object.hasOwn(data ?? {}, 'responseMode');
  const keys = ['contractVersion', 'message'];
  if (hasContinuation) keys.push('continuation');
  if (hasResponseMode) keys.push('responseMode');
  if (!exactKeys(data, keys)) {
    throw new HttpsError('invalid-argument', 'Contrato de chamada inválido.');
  }
}

async function deriveServerAuthorization({ request, uid, ownerAuthority, authorizationReader, HttpsError }) {
  const serverAuthorization = await authorizationReader({ uid, ownerAuthority });
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
