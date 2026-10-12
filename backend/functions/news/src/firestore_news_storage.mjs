import {
  NEWS_CATEGORIES,
  NEWS_COLLECTIONS,
  NEWS_DAILY_REQUEST_LIMIT,
  NEWS_SCHEMA_VERSION,
  fail,
} from '../shared/news_contract.mjs';

const leaseDurationMs = 60 * 1000;
const circuitDelayMs = 30 * 60 * 1000;

/// Storage global e atômico: reserva orçamento antes da rede e publica as três
/// categorias juntas. Nenhum UID, carteira ou dado financeiro participa.
export function createFirestoreNewsStorage({ firestore, Timestamp }) {
  if (!firestore || !Timestamp || typeof Timestamp.fromDate !== 'function') {
    throw new TypeError('news_firestore_dependencies_invalid');
  }
  const reference = (collection, id) => firestore.collection(collection).doc(id);
  const toTimestamp = (value) => Timestamp.fromDate(new Date(value));

  return Object.freeze({
    async claim({ requestId, now, requestCount }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(NEWS_COLLECTIONS.requests, requestId);
        const leaseRef = reference(NEWS_COLLECTIONS.leases, 'current');
        const circuitRef = reference(NEWS_COLLECTIONS.circuits, 'current');
        const usageRef = reference(NEWS_COLLECTIONS.usage, utcDay(now));
        const [requestSnapshot, leaseSnapshot, circuitSnapshot, usageSnapshot] =
            await Promise.all([
              transaction.get(requestRef),
              transaction.get(leaseRef),
              transaction.get(circuitRef),
              transaction.get(usageRef),
            ]);
        if (requestSnapshot.exists) {
          const status = requestSnapshot.data()?.status;
          return Object.freeze({
            kind: status === 'completed' ? 'completed' : status === 'failed' ? 'failed' : 'leased',
          });
        }
        const circuit = circuitSnapshot.exists ? circuitSnapshot.data() : null;
        if (circuit?.nextRetryAt?.toDate?.() > now) {
          return Object.freeze({ kind: 'circuit_open' });
        }
        const lease = leaseSnapshot.exists ? leaseSnapshot.data() : null;
        if (lease?.expiresAt?.toDate?.() > now) {
          return Object.freeze({ kind: 'leased' });
        }
        const used = usageSnapshot.exists ? usageSnapshot.data()?.requestCount : 0;
        if (!Number.isInteger(used) || used < 0 ||
            !Number.isInteger(requestCount) || requestCount <= 0 ||
            used + requestCount > NEWS_DAILY_REQUEST_LIMIT) {
          fail('news_daily_limit_reached');
        }
        transaction.set(usageRef, {
          dayUtc: utcDay(now),
          requestCount: used + requestCount,
          limit: NEWS_DAILY_REQUEST_LIMIT,
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: NEWS_SCHEMA_VERSION,
        });
        transaction.set(leaseRef, {
          requestId,
          expiresAt: Timestamp.fromDate(new Date(now.getTime() + leaseDurationMs)),
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: NEWS_SCHEMA_VERSION,
        });
        transaction.set(requestRef, {
          requestId,
          status: 'claimed',
          requestCount,
          createdAt: Timestamp.fromDate(now),
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: NEWS_SCHEMA_VERSION,
        });
        return Object.freeze({ kind: 'claimed' });
      });
    },

    async complete({ requestId, feeds, now }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(NEWS_COLLECTIONS.requests, requestId);
        const leaseRef = reference(NEWS_COLLECTIONS.leases, 'current');
        const circuitRef = reference(NEWS_COLLECTIONS.circuits, 'current');
        const [requestSnapshot, leaseSnapshot] = await Promise.all([
          transaction.get(requestRef),
          transaction.get(leaseRef),
        ]);
        if (requestSnapshot.data()?.status === 'completed') return;
        if (requestSnapshot.data()?.status !== 'claimed' ||
            leaseSnapshot.data()?.requestId !== requestId ||
            !Array.isArray(feeds) || feeds.length !== NEWS_CATEGORIES.length) {
          fail('news_completion_state_invalid');
        }
        for (const feed of feeds) {
          transaction.set(
            reference(NEWS_COLLECTIONS.feeds, feed.category),
            firestoreFeed(feed, toTimestamp),
          );
        }
        transaction.update(requestRef, {
          status: 'completed',
          categoryCount: feeds.length,
          articleCount: feeds.reduce((sum, feed) => sum + feed.articles.length, 0),
          completedAt: Timestamp.fromDate(now),
          updatedAt: Timestamp.fromDate(now),
        });
        transaction.delete(leaseRef);
        transaction.delete(circuitRef);
      });
    },

    async fail({ requestId, now, code }) {
      return firestore.runTransaction(async (transaction) => {
        const requestRef = reference(NEWS_COLLECTIONS.requests, requestId);
        const leaseRef = reference(NEWS_COLLECTIONS.leases, 'current');
        const circuitRef = reference(NEWS_COLLECTIONS.circuits, 'current');
        const [requestSnapshot, leaseSnapshot, circuitSnapshot] = await Promise.all([
          transaction.get(requestRef),
          transaction.get(leaseRef),
          transaction.get(circuitRef),
        ]);
        if (requestSnapshot.exists && requestSnapshot.data()?.status !== 'completed') {
          transaction.update(requestRef, {
            status: 'failed',
            failureCode: safeCode(code),
            failedAt: Timestamp.fromDate(now),
            updatedAt: Timestamp.fromDate(now),
          });
        }
        if (leaseSnapshot.data()?.requestId === requestId) transaction.delete(leaseRef);
        const failures = circuitSnapshot.exists
          ? circuitSnapshot.data()?.failureCount
          : 0;
        transaction.set(circuitRef, {
          failureCount: Number.isInteger(failures) && failures >= 0 ? failures + 1 : 1,
          lastFailureCode: safeCode(code),
          nextRetryAt: Timestamp.fromDate(new Date(now.getTime() + circuitDelayMs)),
          updatedAt: Timestamp.fromDate(now),
          schemaVersion: NEWS_SCHEMA_VERSION,
        });
      });
    },

    async readFeeds() {
      const snapshots = await Promise.all(
        NEWS_CATEGORIES.map((category) =>
          reference(NEWS_COLLECTIONS.feeds, category.id).get()),
      );
      return snapshots.filter((snapshot) => snapshot.exists).map((snapshot) => snapshot.data());
    },
  });
}

function firestoreFeed(feed, toTimestamp) {
  return {
    category: feed.category,
    provider: feed.provider,
    fetchedAt: toTimestamp(feed.fetchedAt),
    staleAfter: toTimestamp(feed.staleAfter),
    articles: feed.articles.map((article) => ({
      id: article.id,
      title: article.title,
      source: article.source,
      articleUrl: article.articleUrl,
      publishedAt: toTimestamp(article.publishedAt),
    })),
    schemaVersion: feed.schemaVersion,
  };
}

function utcDay(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    fail('news_usage_day_invalid');
  }
  return value.toISOString().slice(0, 10);
}

function safeCode(value) {
  return typeof value === 'string' && /^news_[a-z0-9_]{3,80}$/.test(value)
    ? value
    : 'news_refresh_failed';
}
