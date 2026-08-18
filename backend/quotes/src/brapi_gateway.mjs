import {
  DEFAULT_DECLARED_DELAY_SECONDS,
  DEFAULT_STALE_AFTER_SECONDS,
  fail,
  normalizeTargets,
} from './quote_contract.mjs';
import { QuoteStatus } from './quote_mapper.mjs';

const BRAPI_ENDPOINT = 'https://brapi.dev/api/quote/';

/// Adapter BRAPI isolado: a resposta externa jamais sai deste arquivo como
/// preço decimal/floating point ou contrato da aplicação.
export class BrapiDelayedQuoteGateway {
  constructor({ fetchImpl = globalThis.fetch, token = () => null, clock }) {
    if (typeof fetchImpl !== 'function' || typeof token !== 'function' || typeof clock !== 'function') {
      throw new TypeError('quote_invalid_brapi_dependencies');
    }
    this.fetchImpl = fetchImpl;
    this.token = token;
    this.clock = clock;
  }

  async fetchBatch(targets) {
    const normalizedTargets = normalizeTargets(targets);
    const apiToken = this.token();
    if (typeof apiToken !== 'string' || apiToken.trim().length === 0) {
      fail('quote_provider_not_configured');
    }
    const symbols = normalizedTargets.map((target) => target.ticker).join(',');
    const url = new URL(`${BRAPI_ENDPOINT}${symbols}`);
    url.searchParams.set('range', '1d');
    url.searchParams.set('interval', '1d');
    url.searchParams.set('fundamental', 'false');
    url.searchParams.set('token', apiToken);
    const response = await this.fetchImpl(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });
    if (!response || response.ok !== true) {
      fail('quote_provider_unavailable');
    }
    const payload = await response.json();
    return mapBrapiPayload({ payload, targets: normalizedTargets, capturedAt: this.clock() });
  }
}

/// Permite validação em sandbox público sem token apenas por teste explícito.
/// O runtime falha fechado sem Secret Manager configurado.
export function mapBrapiPayload({ payload, targets, capturedAt }) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || !Array.isArray(payload.results)) {
    fail('quote_provider_invalid_payload');
  }
  if (!(capturedAt instanceof Date) || Number.isNaN(capturedAt.getTime())) {
    fail('quote_provider_invalid_capture_time');
  }
  const targetsByTicker = new Map(normalizeTargets(targets).map((target) => [target.ticker, target]));
  const output = [];
  const seen = new Set();
  for (const result of payload.results) {
    if (!result || typeof result !== 'object' || Array.isArray(result)) fail('quote_provider_invalid_result');
    const ticker = result.symbol;
    const target = targetsByTicker.get(ticker);
    if (!target || seen.has(ticker)) fail('quote_provider_unexpected_result');
    seen.add(ticker);
    output.push(Object.freeze({
      ticker,
      assetType: target.assetType,
      currencyCode: 'BRL',
      priceScaled: decimalToScaled(result.regularMarketPrice, 6, 'quote_provider_invalid_price'),
      variationBasisPoints: decimalToScaled(
        result.regularMarketChangePercent,
        2,
        'quote_provider_invalid_variation',
        { allowNegative: true },
      ),
      observedAt: requireObservedAt(result.regularMarketTime, capturedAt),
      capturedAt: capturedAt.toISOString(),
      declaredDelaySeconds: DEFAULT_DECLARED_DELAY_SECONDS,
      staleAfter: new Date(capturedAt.getTime() + DEFAULT_STALE_AFTER_SECONDS * 1000).toISOString(),
      status: marketStatus(result.marketState),
    }));
  }
  return Object.freeze(output);
}

function requireObservedAt(value, capturedAt) {
  const parsed = typeof value === 'string' ? new Date(value) : new Date(Number(value) * 1000);
  if (Number.isNaN(parsed.getTime()) || parsed > capturedAt) fail('quote_provider_invalid_observed_at');
  return parsed.toISOString();
}

function marketStatus(value) {
  if (typeof value !== 'string') fail('quote_provider_invalid_market_state');
  if (value === 'CLOSED') return QuoteStatus.MARKET_CLOSED;
  if (value === 'REGULAR') return QuoteStatus.DELAYED;
  fail('quote_provider_unavailable_market_state');
}

function decimalToScaled(value, scale, errorCode, { allowNegative = false } = {}) {
  const text = typeof value === 'number' && Number.isFinite(value)
      ? value.toString()
      : typeof value === 'string' ? value : null;
  const expression = allowNegative ? /^-?\d+(\.\d+)?$/ : /^\d+(\.\d+)?$/;
  if (text === null || !expression.test(text)) fail(errorCode);
  const negative = text.startsWith('-');
  const [integer, fraction = ''] = (negative ? text.slice(1) : text).split('.');
  if (fraction.length > scale) fail(errorCode);
  const scaled = BigInt(integer) * (10n ** BigInt(scale)) + BigInt((fraction + '0'.repeat(scale)).slice(0, scale));
  if ((!allowNegative && scaled <= 0n) || scaled > 999999999999n) fail(errorCode);
  return Number(negative ? -scaled : scaled);
}
