import { createHash } from 'node:crypto';

import { requireTicker } from '../shared/quote_contract.mjs';
import { QUOTE_CATALOG_COLLECTION } from './firestore_quote_catalog.mjs';

export const QUOTE_DEMAND_COLLECTION = '_marketQuoteDemands';

/// Sincroniza demanda owner-scoped em um catálogo global opaco. A abertura
/// deste bloco descarta UID, carteira, quantidade, custo e nome antes da
/// persistência e jamais chama o provedor externo.
export function createFirestoreQuoteCatalogSync({ firestore, Timestamp, logger = console }) {
  if (!firestore || typeof firestore.runTransaction !== 'function' ||
      !Timestamp || typeof Timestamp.fromDate !== 'function') {
    throw new TypeError('quote_invalid_catalog_sync_dependencies');
  }
  return async function syncCatalog(event) {
    const userId = requireIdentifier(event?.params?.userId);
    const assetId = requireIdentifier(event?.params?.assetId);
    const before = mapAssetSnapshot(event?.data?.before, userId);
    const after = mapAssetSnapshot(event?.data?.after, userId);
    if (before === null && after === null) return;
    if (before && after && before.ticker !== after.ticker) fail('quote_asset_ticker_changed');
    const eventTime = requireDate(event?.time, 'quote_invalid_catalog_event_time');
    const next = after ?? Object.freeze({
      ticker: before.ticker,
      assetType: before.assetType,
      active: false,
      revision: before.revision,
      sourceUpdatedAt: eventTime,
    });
    const demandId = createHash('sha256').update(`${userId}\u0000${assetId}`).digest('hex');
    const demandRef = firestore.collection(QUOTE_DEMAND_COLLECTION).doc(demandId);
    const catalogRef = firestore.collection(QUOTE_CATALOG_COLLECTION).doc(next.ticker);
    const result = await firestore.runTransaction(async (transaction) => {
      const existingSnapshot = await transaction.get(demandRef);
      const existing = existingSnapshot.exists ? existingSnapshot.data() : null;
      if (existing && compareVersion(next, existing) <= 0) return { kind: 'ignored' };
      const demandQuery = firestore.collection(QUOTE_DEMAND_COLLECTION)
          .where('ticker', '==', next.ticker).where('active', '==', true);
      const [otherDemands, currentCatalog] = await Promise.all([
        transaction.get(demandQuery), transaction.get(catalogRef),
      ]);
      const activeTypes = otherDemands.docs
          .filter((document) => document.id !== demandId)
          .map((document) => document.data()?.assetType)
          .filter((value) => value === 'stock' || value === 'fii');
      if (next.active) activeTypes.push(next.assetType);
      const types = new Set(activeTypes);
      const demandCount = activeTypes.length;
      const now = Timestamp.fromDate(eventTime);
      transaction.set(demandRef, {
        ticker: next.ticker,
        assetType: next.assetType,
        active: next.active,
        sourceRevision: next.revision,
        sourceUpdatedAt: Timestamp.fromDate(next.sourceUpdatedAt),
        updatedAt: now,
        schemaVersion: 1,
      });
      const previous = currentCatalog.exists ? currentCatalog.data() : null;
      const assetType = types.size === 1 ? [...types][0] : next.assetType;
      transaction.set(catalogRef, {
        ticker: next.ticker,
        assetType,
        enabled: demandCount > 0 && types.size === 1,
        demandCount,
        lastDemandAt: now,
        updatedAt: now,
        schemaVersion: 2,
      });
      return {
        kind: demandCount === 0 ? 'retired' : types.size === 1 ? 'active' : 'conflict',
        changed: previous?.demandCount !== demandCount || previous?.enabled !== (demandCount > 0 && types.size === 1),
      };
    });
    logger.info({ event: 'quote_catalog_sync_completed', result: result.kind, changed: result.changed === true });
  };
}

export function createQuoteCatalogDocumentWritten({ onDocumentWritten, options, syncCatalog }) {
  if (typeof onDocumentWritten !== 'function' || !options || typeof syncCatalog !== 'function') {
    throw new TypeError('quote_invalid_catalog_trigger_dependencies');
  }
  return onDocumentWritten({
    ...options,
    document: 'users/{userId}/investmentAssets/{assetId}',
  }, syncCatalog);
}

function mapAssetSnapshot(snapshot, userId) {
  if (!snapshot?.exists) return null;
  const data = snapshot.data();
  if (!data || typeof data !== 'object' || Array.isArray(data) || data.ownerId !== userId ||
      !Number.isInteger(data.revision) || data.revision < 1 ||
      ![1, 2].includes(data.schemaVersion) || !['stock', 'fii'].includes(data.assetType)) {
    fail('quote_invalid_asset_demand');
  }
  const ticker = requireTicker(data.ticker);
  const updatedAt = requireDate(data.updatedAt?.toDate?.(), 'quote_invalid_asset_demand');
  const archived = data.schemaVersion === 1 ? false : data.isArchived;
  if (typeof archived !== 'boolean') fail('quote_invalid_asset_demand');
  return Object.freeze({
    ticker,
    assetType: data.assetType,
    active: !archived,
    revision: data.revision,
    sourceUpdatedAt: updatedAt,
  });
}

function compareVersion(next, existing) {
  const currentDate = existing?.sourceUpdatedAt?.toDate?.();
  if (!(currentDate instanceof Date) || Number.isNaN(currentDate.getTime()) ||
      !Number.isInteger(existing?.sourceRevision)) return 1;
  const byTime = next.sourceUpdatedAt.getTime() - currentDate.getTime();
  return byTime !== 0 ? byTime : next.revision - existing.sourceRevision;
}

function requireDate(value, code) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) fail(code);
  return date;
}

function requireIdentifier(value) {
  if (typeof value !== 'string' || value.length < 1 || value.length > 256) {
    fail('quote_invalid_catalog_event_identity');
  }
  return value;
}

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
