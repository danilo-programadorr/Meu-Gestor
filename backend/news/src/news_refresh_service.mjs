import {
  NEWS_CATEGORIES,
  NEWS_REQUESTS_PER_REFRESH,
  fail,
  requireRequestId,
} from './news_contract.mjs';

export class MarketNewsRefreshService {
  constructor({ storage, gateway, clock, logger = { info() {}, warn() {} } }) {
    if (!storage ||
        typeof storage.claim !== 'function' ||
        typeof storage.complete !== 'function' ||
        typeof storage.fail !== 'function' ||
        typeof storage.readFeeds !== 'function' ||
        !gateway ||
        typeof gateway.fetchCategory !== 'function' ||
        typeof clock !== 'function') {
      throw new TypeError('news_refresh_dependencies_invalid');
    }
    this.storage = storage;
    this.gateway = gateway;
    this.clock = clock;
    this.logger = logger;
  }

  async refresh({ requestId }) {
    const normalizedRequestId = requireRequestId(requestId);
    const now = this.clock();
    const claim = await this.storage.claim({
      requestId: normalizedRequestId,
      now,
      requestCount: NEWS_REQUESTS_PER_REFRESH,
    });
    if (claim.kind === 'completed') return this.storage.readFeeds();
    if (claim.kind !== 'claimed') fail(`news_refresh_${claim.kind}`);
    try {
      const feeds = await Promise.all(
        NEWS_CATEGORIES.map((category) => this.gateway.fetchCategory(category.id)),
      );
      if (feeds.length !== NEWS_CATEGORIES.length ||
          feeds.some((feed, index) => feed?.category !== NEWS_CATEGORIES[index].id)) {
        fail('news_gateway_batch_invalid');
      }
      await this.storage.complete({
        requestId: normalizedRequestId,
        feeds,
        now: this.clock(),
      });
      this.logger.info({
        event: 'news_refresh_completed',
        categoryCount: feeds.length,
        articleCount: feeds.reduce((sum, feed) => sum + feed.articles.length, 0),
      });
      return feeds;
    } catch (error) {
      const code = safeErrorCode(error);
      await this.storage.fail({
        requestId: normalizedRequestId,
        now: this.clock(),
        code,
      });
      this.logger.warn({ event: 'news_refresh_failed', code });
      throw safeFailure(code);
    }
  }
}

function safeErrorCode(error) {
  return typeof error?.code === 'string' && /^news_[a-z0-9_]{3,80}$/.test(error.code)
    ? error.code
    : 'news_refresh_failed';
}

function safeFailure(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}
