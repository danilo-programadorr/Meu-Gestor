import { QUOTE_COLLECTIONS, QUOTE_SCHEMA_VERSION } from '../shared/quote_contract.mjs';

const requestRetentionMs = 30 * 24 * 60 * 60 * 1000;
const historyRetentionMs = 93 * 24 * 60 * 60 * 1000;

/// Adaptador Admin: todas as transações usam apenas coleções globais de
/// mercado; UID, carteira, posição, operação e valor do usuário não entram.
export function createFirestoreQuoteStorage({ firestore, Timestamp }) {
  if (!firestore || !Timestamp || typeof Timestamp.fromDate !== 'function') {
    throw new TypeError('quote_invalid_firestore_storage_dependencies');
  }
  const reference = (collection, id) => firestore.collection(collection).doc(id);
  const requestIdFor = (requestId, ticker) => `${requestId}__${ticker}`;
  const toTimestamp = (value) => Timestamp.fromDate(new Date(value));

  return Object.freeze({
    async claim({ requestId, target, now, leaseExpiresAt }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(QUOTE_COLLECTIONS.requests, requestIdFor(requestId, target.ticker));
        const leaseRef = reference(QUOTE_COLLECTIONS.leases, target.ticker);
        const circuitRef = reference(QUOTE_COLLECTIONS.circuits, target.ticker);
        const [requestSnapshot, leaseSnapshot, circuitSnapshot] = await Promise.all([
          transaction.get(requestRef), transaction.get(leaseRef), transaction.get(circuitRef),
        ]);
        const existing = requestSnapshot.exists ? requestSnapshot.data() : null;
        if (existing?.status === 'completed') return Object.freeze({ kind: 'completed', target });
        const circuit = circuitSnapshot.exists ? circuitSnapshot.data() : null;
        if (circuit?.nextRetryAt?.toDate?.() > now) {
          transaction.set(requestRef, requestDocument({ requestId, target, now, status: 'circuitOpen' }), { merge: true });
          return Object.freeze({ kind: 'circuitOpen', target });
        }
        const lease = leaseSnapshot.exists ? leaseSnapshot.data() : null;
        if (lease?.expiresAt?.toDate?.() > now && lease.requestId !== requestId) {
          transaction.set(requestRef, requestDocument({ requestId, target, now, status: 'leased' }), { merge: true });
          return Object.freeze({ kind: 'leased', target });
        }
        transaction.set(leaseRef, {
          requestId,
          ticker: target.ticker,
          assetType: target.assetType,
          expiresAt: Timestamp.fromDate(leaseExpiresAt),
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: QUOTE_SCHEMA_VERSION,
        });
        transaction.set(requestRef, requestDocument({ requestId, target, now, status: 'claimed' }));
        return Object.freeze({ kind: 'claimed', target });
      });
    },

    async complete({ requestId, target, quote, now }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(QUOTE_COLLECTIONS.requests, requestIdFor(requestId, target.ticker));
        const leaseRef = reference(QUOTE_COLLECTIONS.leases, target.ticker);
        const snapshotRef = reference(QUOTE_COLLECTIONS.snapshots, target.ticker);
        const historyBucket = marketDayFor(quote.observedAt);
        const historyRef = firestore.collection(QUOTE_COLLECTIONS.history)
            .doc(target.ticker).collection('quoteDays').doc(historyBucket);
        const circuitRef = reference(QUOTE_COLLECTIONS.circuits, target.ticker);
        const [requestSnapshot, leaseSnapshot, currentSnapshot, currentHistory] = await Promise.all([
          transaction.get(requestRef), transaction.get(leaseRef), transaction.get(snapshotRef),
          transaction.get(historyRef),
        ]);
        if (requestSnapshot.data()?.status === 'completed') return Object.freeze({ written: false, idempotent: true });
        if (leaseSnapshot.data()?.requestId !== requestId) return Object.freeze({ written: false, idempotent: false });
        const current = currentSnapshot.exists ? currentSnapshot.data() : null;
        const incomingObservedAt = new Date(quote.observedAt);
        const incomingCapturedAt = new Date(quote.capturedAt);
        const currentObservedAt = current?.observedAt?.toDate?.();
        const currentCapturedAt = current?.capturedAt?.toDate?.();
        // Abertura da ordenação composta: uma captura mais nova do mesmo
        // negócio pode promover o snapshot para último fechamento e renovar
        // sua validade, sem permitir que observação antiga substitua a atual.
        const shouldWrite = !currentObservedAt ||
          incomingObservedAt > currentObservedAt ||
          (incomingObservedAt.getTime() === currentObservedAt.getTime() &&
            (!currentCapturedAt || incomingCapturedAt > currentCapturedAt));
        if (shouldWrite) {
          const persistedQuote = {
            ...quote,
            observedAt: toTimestamp(quote.observedAt),
            capturedAt: toTimestamp(quote.capturedAt),
            staleAfter: toTimestamp(quote.staleAfter),
          };
          transaction.set(snapshotRef, persistedQuote);
          const historical = currentHistory.exists ? currentHistory.data() : null;
          const historicalObservedAt = historical?.observedAt?.toDate?.();
          const historicalCapturedAt = historical?.capturedAt?.toDate?.();
          const shouldWriteHistory = !historicalObservedAt ||
            incomingObservedAt > historicalObservedAt ||
            (incomingObservedAt.getTime() === historicalObservedAt.getTime() &&
              (!historicalCapturedAt || incomingCapturedAt > historicalCapturedAt));
          if (shouldWriteHistory) {
            transaction.set(historyRef, {
              ...persistedQuote,
              bucketDate: historyBucket,
              expiresAt: Timestamp.fromDate(new Date(incomingObservedAt.getTime() + historyRetentionMs)),
            });
          }
        }
        transaction.set(requestRef, requestDocument({
          requestId, target, now, status: 'completed', snapshotWritten: shouldWrite,
        }), { merge: true });
        transaction.delete(leaseRef);
        transaction.delete(circuitRef);
        return Object.freeze({ written: shouldWrite, idempotent: false });
      });
    },

    async fail({ requestId, target, now, code, maximumCircuitDelayMs }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(QUOTE_COLLECTIONS.requests, requestIdFor(requestId, target.ticker));
        const leaseRef = reference(QUOTE_COLLECTIONS.leases, target.ticker);
        const circuitRef = reference(QUOTE_COLLECTIONS.circuits, target.ticker);
        const [leaseSnapshot, circuitSnapshot] = await Promise.all([
          transaction.get(leaseRef), transaction.get(circuitRef),
        ]);
        const previousFailures = Number.isInteger(circuitSnapshot.data()?.failureCount)
            ? circuitSnapshot.data().failureCount : 0;
        const failureCount = Math.min(previousFailures + 1, 12);
        const delayMs = Math.min(60 * 1000 * (2 ** (failureCount - 1)), maximumCircuitDelayMs);
        transaction.set(circuitRef, {
          ticker: target.ticker,
          failureCount,
          lastFailureCode: code,
          nextRetryAt: Timestamp.fromDate(new Date(now.getTime() + delayMs)),
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: QUOTE_SCHEMA_VERSION,
        });
        transaction.set(requestRef, requestDocument({ requestId, target, now, status: 'failed', code }), { merge: true });
        if (leaseSnapshot.data()?.requestId === requestId) transaction.delete(leaseRef);
      });
    },

    async read(tickers) {
      const snapshots = await Promise.all(tickers.map((ticker) => reference(QUOTE_COLLECTIONS.snapshots, ticker).get()));
      return Object.freeze(snapshots.filter((snapshot) => snapshot.exists).map((snapshot) => snapshot.data()));
    },
  });
}

function marketDayFor(value) {
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) throw new TypeError('quote_invalid_history_time');
  // A B3 usa o dia civil de São Paulo; formatToParts evita depender do fuso do
  // processo e mantém a chave diária determinística em viradas de mês/ano.
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(instant);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function requestDocument({ requestId, target, now, status, code = null, snapshotWritten = null }) {
  // Metadado técnico sem conteúdo financeiro; a política TTL externa continua
  // desativada até autorização e mantém a idempotência por trinta dias.
  return {
    requestId,
    ticker: target.ticker,
    assetType: target.assetType,
    status,
    ...(code === null ? {} : { code }),
    ...(snapshotWritten === null ? {} : { snapshotWritten }),
    updatedAt: now,
    expiresAt: new Date(now.getTime() + requestRetentionMs),
    schemaVersion: QUOTE_SCHEMA_VERSION,
  };
}
