import {
  NEWS_ARTICLES_PER_CATEGORY,
  NEWS_MAX_ARTICLE_AGE_MS,
  fail,
  feedDocument,
  requireCategory,
} from './news_contract.mjs';

const MARKET_AUX_ENDPOINT = 'https://api.marketaux.com/v1/news/all';

export class MarketauxNewsGateway {
  constructor({ fetchImpl = globalThis.fetch, apiToken, clock, timeoutMs = 10000 }) {
    if (typeof fetchImpl !== 'function' ||
        typeof apiToken !== 'function' ||
        typeof clock !== 'function') {
      throw new TypeError('news_gateway_dependencies_invalid');
    }
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1000 || timeoutMs > 15000) {
      throw new TypeError('news_gateway_timeout_invalid');
    }
    this.fetchImpl = fetchImpl;
    this.apiToken = apiToken;
    this.clock = clock;
    this.timeoutMs = timeoutMs;
  }

  async fetchCategory(categoryId) {
    const category = requireCategory(categoryId);
    const token = this.apiToken();
    if (typeof token !== 'string' || token.trim().length === 0) {
      fail('news_provider_not_configured');
    }
    const url = new URL(MARKET_AUX_ENDPOINT);
    const requestedAt = this.clock();
    if (!(requestedAt instanceof Date) || Number.isNaN(requestedAt.getTime())) {
      fail('news_capture_time_invalid');
    }

    // Force recency because search queries default to relevance in Marketaux.
    url.searchParams.set('api_token', token);
    url.searchParams.set('language', 'pt');
    url.searchParams.set('search', category.search);
    url.searchParams.set('published_after', formatProviderDate(
      new Date(requestedAt.getTime() - NEWS_MAX_ARTICLE_AGE_MS),
    ));
    url.searchParams.set('sort', 'published_on');
    url.searchParams.set('limit', String(NEWS_ARTICLES_PER_CATEGORY));
    url.searchParams.set('page', '1');
    let response;
    try {
      response = await this.fetchImpl(url, {
        method: 'GET',
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      fail(error?.name === 'TimeoutError' || error?.name === 'AbortError'
        ? 'news_provider_timeout'
        : 'news_provider_unavailable');
    }
    if (!response || response.ok !== true) {
      fail(response?.status === 429
        ? 'news_provider_quota_exceeded'
        : 'news_provider_unavailable');
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      fail('news_provider_payload_invalid');
    }
    return mapMarketauxPayload({ category: category.id, payload, fetchedAt: this.clock() });
  }
}

function formatProviderDate(value) {
  return value.toISOString().slice(0, 19);
}

export function mapMarketauxPayload({ category, payload, fetchedAt }) {
  requireCategory(category);
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
      !Array.isArray(payload.data)) {
    fail('news_provider_payload_invalid');
  }
  if (payload.data.length > NEWS_ARTICLES_PER_CATEGORY) {
    fail('news_provider_result_limit_exceeded');
  }
  const articles = payload.data.map((article) => {
    if (!article || typeof article !== 'object' || Array.isArray(article)) {
      fail('news_provider_article_invalid');
    }
    return {
      id: article.uuid,
      title: article.title,
      source: article.source,
      articleUrl: article.url,
      publishedAt: article.published_at,
    };
  });
  return feedDocument({ category, articles, fetchedAt });
}
