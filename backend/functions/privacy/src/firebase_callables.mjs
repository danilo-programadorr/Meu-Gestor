import { PrivacyBackendFailure } from '../../../privacy/src/errors.mjs';

const PROFILE_FIELDS = Object.freeze([
  'ownerId', 'displayName', 'locale', 'currencyCode', 'timeZone',
  'emailVerifiedSnapshot', 'termsVersionAccepted', 'termsAcceptedAt',
  'privacyVersionAccepted', 'privacyAcceptedAt', 'aiConsentEnabled',
  'aiConsentUpdatedAt', 'analyticsConsentEnabled', 'analyticsConsentUpdatedAt',
  'createdAt', 'updatedAt', 'schemaVersion',
]);

const EMPTY_FIELDS = Object.freeze([]);
const PREPARE_FIELDS = Object.freeze(['confirmationPhrase', 'idempotencyKey', 'type']);
const OPERATION_FIELDS = Object.freeze(['operationId']);
const MAX_AUTH_AGE_MS = 5 * 60 * 1000;

/// Cria a borda Gen 2 por injeção. A composição real injeta Firestore/Admin;
/// os testes usam fakes e não comunicam com Firebase.
export function createFirebasePrivacyCallables({
  onCall,
  HttpsError,
  processor,
  profileReader,
  clock,
  logger = { info: () => undefined },
  options,
}) {
  if (
    typeof onCall !== 'function' || typeof HttpsError !== 'function' ||
    !processor || typeof processor.request !== 'function' ||
    typeof processor.advance !== 'function' || typeof processor.status !== 'function' ||
    typeof processor.authorizeContinuation !== 'function' ||
    typeof profileReader !== 'function' || !clock || typeof clock.now !== 'function' || !options
  ) {
    throw new TypeError('Invalid Firebase Privacy callable dependencies.');
  }

  return Object.freeze({
    preparePrivacyOperation: onCall(options, async (request) => {
      return handleFailure(HttpsError, async () => {
        const actor = await requireCaller({ request, HttpsError, profileReader, clock, requiresRecentAuthentication: true });
        requireExactData(request.data, PREPARE_FIELDS, HttpsError);
        const operation = await processor.request({
          actor,
          type: request.data.type,
          confirmationPhrase: request.data.confirmationPhrase,
          idempotencyKey: request.data.idempotencyKey,
        });
        log(logger, operation, 'prepared');
        return sanitizeOperation(operation);
      });
    }),
    confirmPrivacyOperation: onCall(options, async (request) => {
      return handleFailure(HttpsError, async () => {
        requireExactData(request.data, OPERATION_FIELDS, HttpsError);
        const actor = await requireCaller({
          request, HttpsError, profileReader, clock, requiresRecentAuthentication: true,
          continuation: () => processor.authorizeContinuation({
            ownerId: request.auth.uid,
            operationId: request.data.operationId,
          }),
        });
        const operation = await processor.advance({ actor, operationId: request.data.operationId });
        log(logger, operation, 'advanced');
        return sanitizeOperation(operation);
      });
    }),
    getPrivacyOperationStatus: onCall(options, async (request) => {
      return handleFailure(HttpsError, async () => {
        requireExactData(request.data, OPERATION_FIELDS, HttpsError);
        const actor = await requireCaller({
          request, HttpsError, profileReader, clock, requiresRecentAuthentication: false,
          continuation: () => processor.authorizeContinuation({
            ownerId: request.auth.uid,
            operationId: request.data.operationId,
          }),
        });
        return sanitizeOperation(await processor.status({ actor, operationId: request.data.operationId }));
      });
    }),
  });
}

async function requireCaller({ request, HttpsError, profileReader, clock, requiresRecentAuthentication, continuation }) {
  const uid = request?.auth?.uid;
  if (typeof uid !== 'string' || uid.trim() !== uid || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Autenticação obrigatória.', {
      privacyCode: 'privacy_unauthenticated',
    });
  }
  if (request.auth.token?.email_verified !== true) {
    throw new HttpsError('permission-denied', 'E-mail verificado obrigatório.', {
      privacyCode: 'privacy_email_not_verified',
    });
  }
  if (request.app === null || request.app === undefined) {
    throw new HttpsError('failed-precondition', 'App Check obrigatório.', {
      privacyCode: 'privacy_app_check_required',
    });
  }
  const profile = await profileReader(uid);
  const legalProfileVerified = isCurrentLegalProfile(profile, uid);
  if (!legalProfileVerified && !(typeof continuation === 'function' && await continuation())) {
    throw new HttpsError('permission-denied', 'Perfil válido obrigatório.', {
      privacyCode: 'privacy_legal_profile_required',
    });
  }
  const now = clock.now();
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new HttpsError('internal', 'Relógio do servidor indisponível.', {
      privacyCode: 'privacy_unavailable',
    });
  }
  const authTimeSeconds = request.auth.token?.auth_time;
  const authenticatedAt = typeof authTimeSeconds === 'number'
    ? new Date(authTimeSeconds * 1000)
    : null;
  if (
    requiresRecentAuthentication &&
    (!(authenticatedAt instanceof Date) || Number.isNaN(authenticatedAt.valueOf()) ||
      authenticatedAt > now || now.getTime() - authenticatedAt.getTime() > MAX_AUTH_AGE_MS)
  ) {
    throw new HttpsError('failed-precondition', 'Confirmação recente de identidade obrigatória.', {
      privacyCode: 'privacy_recent_authentication_required',
    });
  }
  return Object.freeze({
    uid,
    authenticated: true,
    appCheckVerified: true,
    emailVerified: true,
    legalProfileVerified: true,
    authenticatedAt: authenticatedAt ?? now,
  });
}

function requireExactData(data, fields, HttpsError) {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Contrato de chamada inválido.');
  }
  const received = Object.keys(data).sort();
  const expected = [...fields].sort();
  if (received.length !== expected.length || received.some((field, index) => field !== expected[index])) {
    throw new HttpsError('invalid-argument', 'Contrato de chamada inválido.');
  }
}

function isCurrentLegalProfile(profile, uid) {
  if (profile === null || typeof profile !== 'object') return false;
  const received = Object.keys(profile).sort();
  const expected = [...PROFILE_FIELDS].sort();
  return received.length === expected.length &&
    received.every((field, index) => field === expected[index]) &&
    profile.ownerId === uid && profile.emailVerifiedSnapshot === true &&
    profile.locale === 'pt-BR' && profile.currencyCode === 'BRL' &&
    profile.timeZone === 'America/Sao_Paulo' && profile.schemaVersion === 1;
}

function sanitizeOperation(operation) {
  if (!operation || typeof operation !== 'object' || typeof operation.operationId !== 'string') {
    throw new Error('Invalid privacy operation result.');
  }
  if (operation.state === 'completed') {
    const receipt = operation.receipt;
    if (!receipt || typeof receipt.receiptId !== 'string') throw new Error('Invalid privacy receipt result.');
    return Object.freeze({
      operationId: operation.operationId,
      type: operation.type,
      state: 'completed',
      receipt: Object.freeze({
        receiptId: receipt.receiptId,
        type: receipt.type,
        result: receipt.result,
        completedAt: serializeServerDate(receipt.completedAt),
        expiresAt: serializeServerDate(receipt.expiresAt),
      }),
    });
  }
  const result = {
    operationId: operation.operationId,
    type: operation.type,
    state: operation.state,
    revision: operation.revision,
    createdAt: serializeServerDate(operation.createdAt),
    updatedAt: serializeServerDate(operation.updatedAt),
  };
  if (operation.receipt) result.receipt = structuredClone(operation.receipt);
  return Object.freeze(result);
}

async function handleFailure(HttpsError, operation) {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (!(error instanceof PrivacyBackendFailure)) {
      throw new HttpsError('internal', 'Operação de privacidade indisponível.');
    }
    const code = switchCode(error.code);
    throw new HttpsError(code, 'Operação de privacidade não concluída.', {
      privacyCode: error.code,
    });
  }
}

function switchCode(code) {
  if (['privacy_invalid_request', 'privacy_invalid_confirmation', 'privacy_cursor_invalid',
    'privacy_invalid_transition'].includes(code)) return 'invalid-argument';
  if (code === 'privacy_operation_not_found') return 'not-found';
  if (code === 'privacy_authorization_denied') return 'permission-denied';
  if (['privacy_operation_conflict', 'privacy_operation_in_progress'].includes(code)) return 'failed-precondition';
  if (code === 'privacy_storage_confirmation_timeout') return 'deadline-exceeded';
  return 'unavailable';
}

function serializeServerDate(value) {
  if (value === null || value === undefined) return null;
  if (!(value instanceof Date) || Number.isNaN(value.valueOf())) {
    throw new Error('Invalid privacy operation timestamp.');
  }
  return value.toISOString();
}

function log(logger, operation, stage) {
  logger.info('privacy_operation', {
    operationId: operation.operationId,
    stage,
    state: operation.state,
  });
}
