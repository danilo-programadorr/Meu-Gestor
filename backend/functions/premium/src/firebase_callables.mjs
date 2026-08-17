
import { defineString } from 'firebase-functions/params';

const PROFILE_FIELDS = Object.freeze([
  'ownerId', 'displayName', 'locale', 'currencyCode', 'timeZone',
  'emailVerifiedSnapshot', 'termsVersionAccepted', 'termsAcceptedAt',
  'privacyVersionAccepted', 'privacyAcceptedAt', 'aiConsentEnabled',
  'aiConsentUpdatedAt', 'analyticsConsentEnabled', 'analyticsConsentUpdatedAt',
  'createdAt', 'updatedAt', 'schemaVersion',
]);

const ENTITLEMENT_FIELDS = Object.freeze([
  'ownerId', 'planId', 'status', 'source', 'environment', 'capabilities',
  'startedAt', 'currentPeriodStart', 'currentPeriodEnd', 'graceUntil',
  'cancelAtPeriodEnd', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt',
  'lastVerifiedAt', 'revision', 'schemaVersion', 'createdAt', 'updatedAt',
]);

export const PREMIUM_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  // O e-mail da identidade de runtime é específico de cada ambiente e nunca
  // entra no repositório. O Firebase CLI o solicita/configura no deploy.
  serviceAccount: defineString('PREMIUM_RUNTIME_SERVICE_ACCOUNT'),
  memory: '256MiB',
  timeoutSeconds: 15,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  enforceAppCheck: true,
});

/// Bootstrap executável em Functions Gen 2. Não conhece compra, token da
/// Play, RTDN nem grant: estes fluxos continuam indisponíveis e falham antes
/// de qualquer escrita até o incremento explicitamente autorizado.
export function createFirebasePremiumCallables({ onCall, HttpsError, firestore }) {
  if (typeof onCall !== 'function' || typeof HttpsError !== 'function' || !firestore) {
    throw new TypeError('Invalid Firebase Premium callable dependencies.');
  }
  return Object.freeze({
    getConfirmedEntitlement: onCall(PREMIUM_FUNCTION_OPTIONS, async (request) => {
      const uid = await requireFinancialCaller({ request, HttpsError, firestore });
      requireEmptyData(request.data, HttpsError);
      const snapshot = await firestore.doc(`users/${uid}/entitlements/premium`).get();
      return Object.freeze({
        entitlement: snapshot.exists ? sanitizeEntitlement(snapshot.data(), uid, HttpsError) : null,
        requiresServerRefresh: false,
      });
    }),
    verifyGooglePlayPurchase: onCall(PREMIUM_FUNCTION_OPTIONS, async (request) => {
      await requireFinancialCaller({ request, HttpsError, firestore });
      requireEmptyData(request.data, HttpsError);
      throw new HttpsError(
        'failed-precondition',
        'A confirmação de compra Premium ainda não está disponível.',
      );
    }),
    restoreGooglePlayPurchase: onCall(PREMIUM_FUNCTION_OPTIONS, async (request) => {
      await requireFinancialCaller({ request, HttpsError, firestore });
      requireEmptyData(request.data, HttpsError);
      throw new HttpsError(
        'failed-precondition',
        'A restauração de compra Premium ainda não está disponível.',
      );
    }),
  });
}

async function requireFinancialCaller({ request, HttpsError, firestore }) {
  const uid = request?.auth?.uid;
  if (typeof uid !== 'string' || uid.trim() !== uid || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Autenticação obrigatória.');
  }
  if (request.auth.token?.email_verified !== true) {
    throw new HttpsError('permission-denied', 'E-mail verificado obrigatório.');
  }
  // enforceAppCheck é aplicado pela plataforma. Esta verificação explícita
  // mantém o comportamento falha-fechada também nos testes/invocadores falsos.
  if (request.app === undefined || request.app === null) {
    throw new HttpsError('failed-precondition', 'App Check obrigatório.');
  }
  const profile = await firestore.doc(`users/${uid}`).get();
  if (!profile.exists || !isCurrentLegalProfile(profile.data(), uid)) {
    throw new HttpsError('permission-denied', 'Perfil válido obrigatório.');
  }
  return uid;
}

function requireEmptyData(data, HttpsError) {
  if (data === null || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).length !== 0) {
    throw new HttpsError('invalid-argument', 'Contrato de chamada inválido.');
  }
}

function isCurrentLegalProfile(data, uid) {
  if (data === null || typeof data !== 'object') return false;
  const keys = Object.keys(data).sort();
  const expected = [...PROFILE_FIELDS].sort();
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) return false;
  return data.ownerId === uid &&
    typeof data.displayName === 'string' &&
    data.locale === 'pt-BR' &&
    data.currencyCode === 'BRL' &&
    data.timeZone === 'America/Sao_Paulo' &&
    data.emailVerifiedSnapshot === true &&
    data.termsVersionAccepted === 'terms-dev-1.0.0' &&
    data.privacyVersionAccepted === 'privacy-dev-1.0.0' &&
    data.schemaVersion === 1 &&
    typeof data.aiConsentEnabled === 'boolean' &&
    typeof data.analyticsConsentEnabled === 'boolean' &&
    hasTimestamp(data.termsAcceptedAt) &&
    hasTimestamp(data.privacyAcceptedAt) &&
    hasTimestamp(data.aiConsentUpdatedAt) &&
    hasTimestamp(data.analyticsConsentUpdatedAt) &&
    hasTimestamp(data.createdAt) &&
    hasTimestamp(data.updatedAt);
}

function sanitizeEntitlement(data, uid, HttpsError) {
  if (data === null || typeof data !== 'object') {
    throw new HttpsError('internal', 'Entitlement inválido.');
  }
  const keys = Object.keys(data).sort();
  const expected = [...ENTITLEMENT_FIELDS].sort();
  if (
    keys.length !== expected.length ||
    keys.some((key, index) => key !== expected[index]) ||
    data.ownerId !== uid
  ) {
    throw new HttpsError('internal', 'Entitlement inválido.');
  }
  return Object.freeze(Object.fromEntries(
    ENTITLEMENT_FIELDS.map((field) => [field, serializeValue(data[field])]),
  ));
}

function hasTimestamp(value) {
  return value !== null && typeof value === 'object' && typeof value.toDate === 'function';
}

function serializeValue(value) {
  if (value === null || typeof value !== 'object') return value;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serializeValue);
  return structuredClone(value);
}
