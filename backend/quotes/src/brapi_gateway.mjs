import {
  DEFAULT_DECLARED_DELAY_SECONDS,
  DEFAULT_STALE_AFTER_SECONDS,
  fail,
  normalizeTargets,
} from './quote_contract.mjs';
import { QuoteStatus } from './quote_mapper.mjs';

const BRAPI_ENDPOINT = 'https://brapi.dev/api/quote/';
const B3_TIME_ZONE = 'America/Sao_Paulo';
const B3_OPEN_MINUTE = 10 * 60;
const B3_CLOSE_MINUTE = 18 * 60;
const CLOSED_REFRESH_GRACE_MINUTES = 45;
const MAX_CLOSED_OBSERVATION_AGE_SECONDS = 4 * 24 * 60 * 60;
const b3Clock = new Intl.DateTimeFormat('en-CA', {
  timeZone: B3_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
});
export const BRAPI_FREE_PLAN_MAX_TARGETS = 1;
export const BRAPI_FREE_PLAN_MAX_ACTIVE_TARGETS = 30;

/// Adapter BRAPI isolado: a resposta externa jamais sai deste arquivo como
/// preço decimal/floating point ou contrato da aplicação.
export class BrapiDelayedQuoteGateway {
  constructor({ fetchImpl = globalThis.fetch, token = () => null, clock, timeoutMs = 10000 }) {
    if (typeof fetchImpl !== 'function' || typeof token !== 'function' || typeof clock !== 'function') {
      throw new TypeError('quote_invalid_brapi_dependencies');
    }
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1000 || timeoutMs > 15000) {
      throw new TypeError('quote_invalid_provider_timeout');
    }
    this.fetchImpl = fetchImpl;
    this.token = token;
    this.clock = clock;
    this.timeoutMs = timeoutMs;
    this.maximumTargetsPerRequest = BRAPI_FREE_PLAN_MAX_TARGETS;
  }

  async fetchBatch(targets) {
    const normalizedTargets = normalizeTargets(targets);
    // O plano Gratuito permite somente um ticker por requisição. Este bloqueio
    // impede que expansão administrativa do catálogo aumente consumo em silêncio.
    if (normalizedTargets.length > BRAPI_FREE_PLAN_MAX_TARGETS) {
      fail('quote_provider_plan_limit_exceeded');
    }
    const apiToken = this.token();
    if (typeof apiToken !== 'string' || apiToken.trim().length === 0) {
      fail('quote_provider_not_configured');
    }
    const symbols = normalizedTargets.map((target) => target.ticker).join(',');
    const url = new URL(`${BRAPI_ENDPOINT}${symbols}`);
    url.searchParams.set('range', '1d');
    url.searchParams.set('interval', '1d');
    url.searchParams.set('fundamental', 'false');
    let response;
    try {
      response = await this.fetchImpl(url, {
        method: 'GET',
        // Abertura do transporte autenticado: a chave permanece no header e
        // não entra em URLs, históricos, diagnósticos ou documentos.
        headers: { Accept: 'application/json', Authorization: `Bearer ${apiToken}` },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      fail(error?.name === 'TimeoutError' || error?.name === 'AbortError'
        ? 'quote_provider_timeout' : 'quote_provider_unavailable');
    }
    if (!response || response.ok !== true) {
      fail('quote_provider_unavailable');
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      fail('quote_provider_invalid_payload');
    }
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
    // Abertura da política de sessão: a BRAPI não declara marketState neste
    // contrato, então classificação e validade derivam de relógio confiável.
    const observedAt = requireObservedAt(result.regularMarketTime, capturedAt);
    const validity = resolveQuoteValidity({ observedAt: new Date(observedAt), capturedAt });
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
      observedAt,
      capturedAt: capturedAt.toISOString(),
      declaredDelaySeconds: DEFAULT_DECLARED_DELAY_SECONDS,
      staleAfter: validity.staleAfter.toISOString(),
      status: validity.status,
    }));
  }
  return Object.freeze(output);
}

function resolveQuoteValidity({ observedAt, capturedAt }) {
  const captured = b3Parts(capturedAt);
  const observed = b3Parts(observedAt);
  const ageSeconds = Math.floor((capturedAt.getTime() - observedAt.getTime()) / 1000);
  const minute = captured.hour * 60 + captured.minute;
  const insideRegularSession = isWeekday(captured) &&
    minute >= B3_OPEN_MINUTE && minute < B3_CLOSE_MINUTE;
  if (insideRegularSession && sameCivilDate(captured, observed)) {
    if (ageSeconds > DEFAULT_STALE_AFTER_SECONDS) fail('quote_provider_stale_quote');
    return Object.freeze({
      status: QuoteStatus.DELAYED,
      staleAfter: new Date(observedAt.getTime() + DEFAULT_STALE_AFTER_SECONDS * 1000),
    });
  }
  if (ageSeconds > MAX_CLOSED_OBSERVATION_AGE_SECONDS) fail('quote_provider_stale_quote');
  return Object.freeze({
    status: QuoteStatus.MARKET_CLOSED,
    staleAfter: insideRegularSession
      ? new Date(capturedAt.getTime() + CLOSED_REFRESH_GRACE_MINUTES * 60 * 1000)
      : nextRegularSessionGrace(captured),
  });
}

function b3Parts(instant) {
  const values = Object.fromEntries(
    b3Clock.formatToParts(instant)
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, Number(part.value)]),
  );
  return Object.freeze({
    year: values.year,
    month: values.month,
    day: values.day,
    hour: values.hour,
    minute: values.minute,
    second: values.second,
  });
}

function sameCivilDate(first, second) {
  return first.year === second.year && first.month === second.month && first.day === second.day;
}

function isWeekday(parts) {
  const weekday = new Date(Date.UTC(parts.year, parts.month - 1, parts.day)).getUTCDay();
  return weekday >= 1 && weekday <= 5;
}

function nextRegularSessionGrace(captured) {
  const capturedMinute = captured.hour * 60 + captured.minute;
  const currentCivilDay = new Date(Date.UTC(captured.year, captured.month - 1, captured.day));
  const currentDayCanStillOpen = isWeekday(captured) && capturedMinute < B3_OPEN_MINUTE;
  let civilDay = currentDayCanStillOpen
    ? currentCivilDay
    : new Date(currentCivilDay.getTime() + 24 * 60 * 60 * 1000);
  while (civilDay.getUTCDay() === 0 || civilDay.getUTCDay() === 6) {
    civilDay = new Date(civilDay.getTime() + 24 * 60 * 60 * 1000);
  }
  return fromB3Civil({
    year: civilDay.getUTCFullYear(),
    month: civilDay.getUTCMonth() + 1,
    day: civilDay.getUTCDate(),
    hour: 10,
    minute: CLOSED_REFRESH_GRACE_MINUTES,
    second: 0,
  });
}

function fromB3Civil(target) {
  const targetAsUtc = Date.UTC(
    target.year, target.month - 1, target.day, target.hour, target.minute, target.second,
  );
  let candidate = targetAsUtc;
  for (let iteration = 0; iteration < 3; iteration += 1) {
    const actual = b3Parts(new Date(candidate));
    const actualAsUtc = Date.UTC(
      actual.year, actual.month - 1, actual.day, actual.hour, actual.minute, actual.second,
    );
    candidate += targetAsUtc - actualAsUtc;
  }
  return new Date(candidate);
}

function requireObservedAt(value, capturedAt) {
  const parsed = typeof value === 'string' ? new Date(value) : new Date(Number(value) * 1000);
  if (Number.isNaN(parsed.getTime()) || parsed > capturedAt) fail('quote_provider_invalid_observed_at');
  return parsed.toISOString();
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
