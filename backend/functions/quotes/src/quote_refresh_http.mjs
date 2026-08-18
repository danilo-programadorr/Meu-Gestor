import { timingSafeEqual } from 'node:crypto';

/// Endpoint exclusivamente interno para o Scheduler futuro. Sem o segredo
/// injetado por Secret Manager, ele não processa nem cria snapshot algum.
export function createQuoteRefreshHttp({ onRequest, options, refreshService, sharedSecret, logger = console }) {
  if (typeof onRequest !== 'function' || !options || !refreshService ||
      typeof refreshService.refresh !== 'function' || typeof sharedSecret !== 'function') {
    throw new TypeError('quote_invalid_http_dependencies');
  }
  return onRequest(options, async (request, response) => {
    if (request.method !== 'POST') {
      return response.status(405).json({ error: 'method_not_allowed' });
    }
    const expected = sharedSecret();
    if (typeof expected !== 'string' || expected.length < 24) {
      logger.warn({ event: 'quote_refresh_not_configured' });
      return response.status(503).json({ error: 'quote_refresh_not_configured' });
    }
    const provided = request.get?.('x-quote-refresh-secret');
    if (!isSameSecret(provided, expected)) {
      logger.warn({ event: 'quote_refresh_unauthorized' });
      return response.status(401).json({ error: 'unauthorized' });
    }
    try {
      const body = request.body;
      if (!body || typeof body !== 'object' || Array.isArray(body) ||
          Object.keys(body).sort().join(',') !== 'requestId,targets') {
        return response.status(400).json({ error: 'invalid_request' });
      }
      const snapshots = await refreshService.refresh({ requestId: body.requestId, targets: body.targets });
      return response.status(200).json({ refreshed: snapshots.length });
    } catch (error) {
      const code = typeof error?.code === 'string' ? error.code : 'quote_refresh_failed';
      logger.warn({ event: 'quote_refresh_rejected', code });
      return response.status(400).json({ error: code });
    }
  });
}

function isSameSecret(provided, expected) {
  if (typeof provided !== 'string') return false;
  const first = Buffer.from(provided);
  const second = Buffer.from(expected);
  return first.length === second.length && timingSafeEqual(first, second);
}
