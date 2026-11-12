import { createHash } from 'node:crypto';

const DEFAULT_LIMIT = 30;
const DEFAULT_WINDOW_MS = 5 * 60 * 1000;
const SCHEMA_VERSION = 1;

/// Limita atomicamente buscas autenticadas sem persistir UID, consulta ou
/// carteira. O hash serve apenas como escopo opaco e nunca é registrado.
export function createFirestoreAssetSearchRateLimiter({
  firestore,
  Timestamp,
  clock = () => new Date(),
  limit = DEFAULT_LIMIT,
  windowMs = DEFAULT_WINDOW_MS,
}) {
  if (!firestore || typeof firestore.runTransaction !== 'function' ||
      !Timestamp || typeof Timestamp.fromDate !== 'function' ||
      typeof clock !== 'function' || !Number.isSafeInteger(limit) || limit < 1 ||
      !Number.isSafeInteger(windowMs) || windowMs < 60_000) {
    throw new TypeError('asset_search_rate_limiter_invalid_dependencies');
  }

  return Object.freeze({
    async consume({ ownerId }) {
      if (typeof ownerId !== 'string' || ownerId.length < 1 || ownerId.length > 256) {
        fail('asset_search_rate_limit_invalid_owner');
      }
      const ownerScope = createHash('sha256').update(ownerId, 'utf8').digest('hex');
      const reference = firestore.collection('_assetSearchRateLimits').doc(ownerScope);
      const now = clock();
      if (!(now instanceof Date) || !Number.isFinite(now.getTime())) {
        fail('asset_search_rate_limit_unavailable');
      }

      try {
        return await firestore.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(reference);
          let windowStartedAt = now;
          let attemptCount = 0;
          if (snapshot.exists) {
            const current = validateStoredWindow(snapshot.data(), ownerScope);
            windowStartedAt = current.windowStartedAt;
            attemptCount = current.attemptCount;
            if (now.getTime() < windowStartedAt.getTime()) {
              fail('asset_search_rate_limit_unavailable');
            }
            if (now.getTime() - windowStartedAt.getTime() >= windowMs) {
              windowStartedAt = now;
              attemptCount = 0;
            }
          }
          if (attemptCount >= limit) fail('asset_search_rate_limit_reached');
          const nextCount = attemptCount + 1;
          const expiresAt = new Date(windowStartedAt.getTime() + windowMs);
          transaction.set(reference, Object.freeze({
            ownerScope,
            windowStartedAt: Timestamp.fromDate(windowStartedAt),
            attemptCount: nextCount,
            expiresAt: Timestamp.fromDate(expiresAt),
            schemaVersion: SCHEMA_VERSION,
          }));
          return Object.freeze({ remaining: limit - nextCount, resetsAt: expiresAt });
        });
      } catch (error) {
        if (error?.code === 'asset_search_rate_limit_reached' ||
            error?.code === 'asset_search_rate_limit_unavailable') {
          throw error;
        }
        fail('asset_search_rate_limit_unavailable');
      }
    },
  });
}

function validateStoredWindow(data, ownerScope) {
  const keys = data && typeof data === 'object' && !Array.isArray(data)
    ? Object.keys(data).sort().join(',')
    : '';
  if (keys !== 'attemptCount,expiresAt,ownerScope,schemaVersion,windowStartedAt' ||
      data.ownerScope !== ownerScope || data.schemaVersion !== SCHEMA_VERSION ||
      !Number.isSafeInteger(data.attemptCount) || data.attemptCount < 1 ||
      typeof data.windowStartedAt?.toDate !== 'function' ||
      typeof data.expiresAt?.toDate !== 'function') {
    fail('asset_search_rate_limit_unavailable');
  }
  const windowStartedAt = data.windowStartedAt.toDate();
  const expiresAt = data.expiresAt.toDate();
  if (!(windowStartedAt instanceof Date) || !(expiresAt instanceof Date) ||
      !Number.isFinite(windowStartedAt.getTime()) ||
      !Number.isFinite(expiresAt.getTime()) ||
      expiresAt.getTime() <= windowStartedAt.getTime()) {
    fail('asset_search_rate_limit_unavailable');
  }
  return Object.freeze({ windowStartedAt, attemptCount: data.attemptCount });
}

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
