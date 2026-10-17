const BRAPI_TICKERS_ENDPOINT = 'https://brapi.dev/api/v2/tickers';
const TICKER_EXPRESSION = /^[A-Z]{4}[0-9]{1,2}$/u;

/// Catálogo remoto fechado: a busca recebe somente texto público, limita a
/// resposta e nunca encaminha identidade, carteira, quantidade ou operação.
export function createBrapiAssetDirectoryGateway({
  fetchImpl = globalThis.fetch,
  token,
  timeoutMs = 5000,
  clock = () => new Date(),
}) {
  if (typeof fetchImpl !== 'function' || typeof token !== 'function' ||
      typeof clock !== 'function' || !Number.isInteger(timeoutMs) ||
      timeoutMs < 1000 || timeoutMs > 10000) {
    throw new TypeError('asset_directory_invalid_dependencies');
  }
  const cache = new Map();

  return Object.freeze({
    async search(rawQuery) {
      const query = requireSearchQuery(rawQuery);
      const now = clock();
      const cached = cache.get(query);
      if (cached && cached.expiresAt > now.getTime()) return cached.results;
      const apiToken = token();
      if (typeof apiToken !== 'string' || apiToken.trim().length === 0) {
        fail('asset_directory_not_configured');
      }
      const url = new URL(BRAPI_TICKERS_ENDPOINT);
      url.searchParams.set('search', query);
      url.searchParams.set('page', '1');
      url.searchParams.set('limit', '8');
      let response;
      try {
        response = await fetchImpl(url, {
          method: 'GET',
          headers: { Accept: 'application/json', Authorization: `Bearer ${apiToken}` },
          signal: AbortSignal.timeout(timeoutMs),
        });
      } catch (error) {
        fail(error?.name === 'TimeoutError' || error?.name === 'AbortError'
          ? 'asset_directory_timeout' : 'asset_directory_unavailable');
      }
      if (!response || response.ok !== true) fail('asset_directory_unavailable');
      let payload;
      try {
        payload = await response.json();
      } catch {
        fail('asset_directory_invalid_payload');
      }
      const results = mapDirectoryPayload(payload);
      if (cache.size >= 100) cache.delete(cache.keys().next().value);
      cache.set(query, Object.freeze({
        expiresAt: now.getTime() + 15 * 60 * 1000,
        results,
      }));
      return results;
    },
  });
}

export function requireSearchQuery(value) {
  if (typeof value !== 'string') fail('asset_directory_invalid_query');
  const normalized = value.trim().replace(/\s+/gu, ' ').toUpperCase();
  if (normalized.length < 2 || normalized.length > 32 ||
      !/^[\p{L}\p{N} .&-]+$/u.test(normalized)) {
    fail('asset_directory_invalid_query');
  }
  return normalized;
}

export function mapDirectoryPayload(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
      !Array.isArray(payload.results)) {
    fail('asset_directory_invalid_payload');
  }
  const mapped = [];
  const seen = new Set();
  for (const item of payload.results) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      fail('asset_directory_invalid_payload');
    }
    const ticker = item.symbol;
    const name = typeof item.longName === 'string' && item.longName.trim().length > 0
      ? item.longName.trim().replace(/\s+/gu, ' ')
      : typeof item.name === 'string' ? item.name.trim().replace(/\s+/gu, ' ') : '';
    const type = directoryType(item);
    if (type === null || !TICKER_EXPRESSION.test(ticker) || name.length < 1 ||
        name.length > 80 || item.isActive === false || seen.has(ticker)) continue;
    seen.add(ticker);
    mapped.push(Object.freeze({ ticker, name, type }));
  }
  return Object.freeze(mapped.slice(0, 8));
}

function directoryType(item) {
  if (item.subType === 'fii') return 'fii';
  if (item.assetType === 'stock' && ['stock', 'unit', null, undefined].includes(item.subType)) {
    return 'stock';
  }
  return null;
}

function fail(code) {
  const error = new Error(code);
  error.code = code;
  throw error;
}
