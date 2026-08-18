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
    typeof profileReader !== 'function' || !clock || typeof clock.now !== 'function' || !options
  ) {
    throw new TypeError('Invalid Firebase Privacy callable dependencies.');
  }

  return Object.freeze({
    preparePrivacyOperation: onCall(options, async (request) => {
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
    }),
    confirmPrivacyOperation: onCall(options, async (request) => {
      const actor = await requireCaller({ request, HttpsError, profileReader, clock, requiresRecentAuthentication: true });
      requireExactData(request.data, OPERATION_FIELDS, HttpsError);
      const operation = await processor.advance({ actor, operationId: request.data.operationId });
      log(logger, operation, 'advanced');
      return sanitizeOperation(operation);
    }),
    getPrivacyOperationStatus: onCall(options, async (request) => {
      const actor = await requireCaller({ request, HttpsError, profileReader, clock, requiresRecentAuthentication: false });
      requireExactData(request.data, OPERATION_FIELDS, HttpsError);
      return sanitizeOperation(await processor.status({ actor, operationId: request.data.operationId }));
    }),
  });
}

async function requireCaller({ request, HttpsError, profileReader, clock, requiresRecentAuthentication }) {
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
  const profile = await profileReader(uid);
  if (!isCurrentLegalProfile(profile, uid)) {
    throw new HttpsError('permission-denied', 'Perfil válido obrigatório.');
  }
  const now = clock.now();
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new HttpsError('internal', 'Relógio do servidor indisponível.');
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
    throw new HttpsError('failed-precondition', 'Confirmação recente de identidade obrigatória.');
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
