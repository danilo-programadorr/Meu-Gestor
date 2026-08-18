import { QUOTE_COLLECTIONS, QUOTE_SCHEMA_VERSION } from '../../../quotes/src/quote_contract.mjs';

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
        const circuitRef = reference(QUOTE_COLLECTIONS.circuits, target.ticker);
        const [requestSnapshot, leaseSnapshot, currentSnapshot] = await Promise.all([
          transaction.get(requestRef), transaction.get(leaseRef), transaction.get(snapshotRef),
        ]);
        if (requestSnapshot.data()?.status === 'completed') return Object.freeze({ written: false, idempotent: true });
        if (leaseSnapshot.data()?.requestId !== requestId) return Object.freeze({ written: false, idempotent: false });
        const current = currentSnapshot.exists ? currentSnapshot.data() : null;
        const incomingObservedAt = new Date(quote.observedAt);
        const currentObservedAt = current?.observedAt?.toDate?.();
        const shouldWrite = !currentObservedAt || incomingObservedAt > currentObservedAt;
        if (shouldWrite) {
          transaction.set(snapshotRef, {
            ...quote,
            observedAt: toTimestamp(quote.observedAt),
            capturedAt: toTimestamp(quote.capturedAt),
            staleAfter: toTimestamp(quote.staleAfter),
          });
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

function requestDocument({ requestId, target, now, status, code = null, snapshotWritten = null }) {
  return {
    requestId,
    ticker: target.ticker,
    assetType: target.assetType,
    status,
    ...(code === null ? {} : { code }),
    ...(snapshotWritten === null ? {} : { snapshotWritten }),
    updatedAt: now,
    schemaVersion: QUOTE_SCHEMA_VERSION,
  };
}
