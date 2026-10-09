const schedulerTimeHeader = 'x-cloudscheduler-scheduletime';

/// Endpoint interno sem alvos no payload. A abertura deste bloco confia a
/// autenticação ao IAM do invocador privado e deriva idempotência do Scheduler.
export function createQuoteRefreshHttp({ onRequest, options, catalog, refreshService, logger = console }) {
  if (typeof onRequest !== 'function' || !options || !catalog ||
      typeof catalog.readActiveTargets !== 'function' || !refreshService ||
      typeof refreshService.refresh !== 'function') {
    throw new TypeError('quote_invalid_http_dependencies');
  }
  return onRequest(options, async (request, response) => {
    if (request.method !== 'POST') {
      return response.status(405).json({ error: 'method_not_allowed' });
    }
    if (request.body != null &&
        (typeof request.body !== 'object' || Array.isArray(request.body) || Object.keys(request.body).length !== 0)) {
      return response.status(400).json({ error: 'invalid_request' });
    }
    const scheduleTime = requireScheduleTime(request.get?.(schedulerTimeHeader));
    if (scheduleTime === null) {
      logger.warn({ event: 'quote_refresh_rejected', code: 'quote_invalid_schedule_time' });
      return response.status(400).json({ error: 'quote_invalid_schedule_time' });
    }
    try {
      const targets = await catalog.readActiveTargets();
      const snapshots = await refreshService.refresh({
        requestId: requestIdFor(scheduleTime),
        targets,
      });
      logger.info({ event: 'quote_refresh_http_completed', targetCount: targets.length, snapshotCount: snapshots.length });
      return response.status(200).json({ refreshed: snapshots.length, targetCount: targets.length });
    } catch (error) {
      const code = safeErrorCode(error);
      const status = statusFor(code);
      logger.warn({ event: 'quote_refresh_rejected', code, status });
      return response.status(status).json({ error: code });
    }
  });
}

function requireScheduleTime(value) {
  if (typeof value !== 'string') return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function requestIdFor(scheduleTime) {
  return `schedule_${scheduleTime.toISOString().replace(/[^0-9]/g, '')}`;
}

function safeErrorCode(error) {
  return typeof error?.code === 'string' && /^quote_[a-z0-9_]{3,72}$/.test(error.code)
      ? error.code : 'quote_refresh_failed';
}

function statusFor(code) {
  if (code.startsWith('quote_catalog_')) return 503;
  if (code === 'quote_provider_not_configured') return 503;
  if (code.startsWith('quote_provider_') || code.startsWith('quote_gateway_')) return 502;
  return 500;
}
