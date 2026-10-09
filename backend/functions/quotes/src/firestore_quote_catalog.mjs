import { MAX_BATCH_SIZE, normalizeTargets } from '../shared/quote_contract.mjs';
import { BRAPI_FREE_PLAN_MAX_TARGETS } from '../shared/brapi_gateway.mjs';

export const QUOTE_CATALOG_COLLECTION = '_marketQuoteCatalog';

/// Catálogo global server-only. A abertura deste bloco impede que carteira,
/// UID ou listas fornecidas pelo aplicativo determinem chamadas ao provedor.
export function createFirestoreQuoteCatalog({
  firestore,
  logger = { info() {}, warn() {} },
  maximumTargets = BRAPI_FREE_PLAN_MAX_TARGETS,
}) {
  if (!firestore || typeof firestore.collection !== 'function') {
    throw new TypeError('quote_invalid_catalog_dependencies');
  }
  if (!Number.isInteger(maximumTargets) || maximumTargets < 1 || maximumTargets > MAX_BATCH_SIZE) {
    throw new TypeError('quote_invalid_catalog_limit');
  }
  return Object.freeze({
    async readActiveTargets() {
      const snapshot = await firestore.collection(QUOTE_CATALOG_COLLECTION)
          .where('enabled', '==', true)
          .limit(maximumTargets + 1)
          .get();
      if (snapshot.size === 0) fail('quote_catalog_empty');
      if (snapshot.size > maximumTargets) fail('quote_catalog_limit_exceeded');
      const targets = snapshot.docs.map(mapCatalogDocument);
      const normalized = normalizeTargets(targets);
      logger.info({ event: 'quote_catalog_loaded', targetCount: normalized.length });
      return normalized;
    },
  });
}

function mapCatalogDocument(snapshot) {
  const data = snapshot.data();
  if (!data || typeof data !== 'object' || Array.isArray(data)) fail('quote_catalog_invalid_document');
  const expected = ['assetType', 'enabled', 'schemaVersion', 'ticker', 'updatedAt'];
  const keys = Object.keys(data).sort();
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index]) ||
      snapshot.id !== data.ticker || data.enabled !== true || data.schemaVersion !== 1 ||
      typeof data.updatedAt?.toDate !== 'function' || Number.isNaN(data.updatedAt.toDate().getTime())) {
    fail('quote_catalog_invalid_document');
  }
  return { ticker: data.ticker, assetType: data.assetType };
}

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
