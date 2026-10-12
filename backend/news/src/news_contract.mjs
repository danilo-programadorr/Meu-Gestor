export const NEWS_PROVIDER = 'marketaux';
export const NEWS_SCHEMA_VERSION = 1;
export const NEWS_ARTICLES_PER_CATEGORY = 3;
export const NEWS_REQUESTS_PER_REFRESH = 3;
export const NEWS_DAILY_REQUEST_LIMIT = 90;
export const NEWS_STALE_AFTER_MS = 3 * 60 * 60 * 1000;

// Freshness is enforced server-side so provider relevance never republishes old news as current.
export const NEWS_MAX_ARTICLE_AGE_MS = 12 * 60 * 60 * 1000;

export const NEWS_COLLECTIONS = Object.freeze({
  feeds: 'marketNewsFeeds',
  leases: '_marketNewsLeases',
  requests: '_marketNewsRefreshRequests',
  circuits: '_marketNewsCircuitBreakers',
  usage: '_marketNewsDailyUsage',
});

// Consultas fechadas impedem que o aplicativo transforme a integração em
// busca arbitrária ou envie dados pessoais ao provedor.
export const NEWS_CATEGORIES = Object.freeze([
  Object.freeze({ id: 'market', label: 'Mercado', search: 'mercado' }),
  Object.freeze({ id: 'economy', label: 'Economia', search: 'economia' }),
  Object.freeze({
    id: 'international',
    label: 'Internacional',
    search: 'internacional',
  }),
]);

export function requireCategory(value) {
  const category = NEWS_CATEGORIES.find((candidate) => candidate.id === value);
  if (!category) fail('news_category_invalid');
  return category;
}

export function requireRequestId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{16,96}$/.test(value)) {
    fail('news_request_id_invalid');
  }
  return value;
}

export function feedDocument({ category, articles, fetchedAt }) {
  const definition = requireCategory(category);
  if (!(fetchedAt instanceof Date) || Number.isNaN(fetchedAt.getTime())) {
    fail('news_capture_time_invalid');
  }
  if (!Array.isArray(articles) || articles.length > NEWS_ARTICLES_PER_CATEGORY) {
    fail('news_article_batch_invalid');
  }
  const ids = new Set();
  const normalized = articles.map((article) => {
    const item = articleDocument(article, fetchedAt);
    if (ids.has(item.id)) fail('news_article_duplicate');
    ids.add(item.id);
    return item;
  }).sort((left, right) => right.publishedAt.localeCompare(left.publishedAt));
  return Object.freeze({
    category: definition.id,
    provider: NEWS_PROVIDER,
    fetchedAt: fetchedAt.toISOString(),
    staleAfter: new Date(fetchedAt.getTime() + NEWS_STALE_AFTER_MS).toISOString(),
    articles: Object.freeze(normalized),
    schemaVersion: NEWS_SCHEMA_VERSION,
  });
}

function articleDocument(article, fetchedAt) {
  if (!article || typeof article !== 'object' || Array.isArray(article)) {
    fail('news_article_invalid');
  }
  const id = requireText(article.id, 'news_article_id_invalid', 8, 128);
  if (!/^[A-Za-z0-9_-]+$/.test(id)) fail('news_article_id_invalid');
  const title = requireText(article.title, 'news_article_title_invalid', 1, 220);
  const source = requireText(article.source, 'news_article_source_invalid', 1, 120);
  const articleUrl = requireHttpsUrl(article.articleUrl);
  const publishedAt = new Date(article.publishedAt);
  if (Number.isNaN(publishedAt.getTime()) ||
      publishedAt.getTime() > fetchedAt.getTime() + 5 * 60 * 1000 ||
      publishedAt.getTime() < fetchedAt.getTime() - NEWS_MAX_ARTICLE_AGE_MS) {
    fail('news_article_published_at_invalid');
  }
  return Object.freeze({
    id,
    title,
    source,
    articleUrl,
    publishedAt: publishedAt.toISOString(),
  });
}

export function normalizeText(value) {
  if (typeof value !== 'string') return null;
  return value.replace(/\s+/gu, ' ').trim();
}

function requireText(value, code, minimum, maximum) {
  const normalized = normalizeText(value);
  if (normalized === null ||
      normalized.length < minimum ||
      normalized.length > maximum ||
      /[\u0000-\u001F\u007F]/u.test(normalized)) {
    fail(code);
  }
  return normalized;
}

function requireHttpsUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) {
    fail('news_article_url_invalid');
  }
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    fail('news_article_url_invalid');
  }
  if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password) {
    fail('news_article_url_invalid');
  }
  return parsed.toString();
}

export function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
