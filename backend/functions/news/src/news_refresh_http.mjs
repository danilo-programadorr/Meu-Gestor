const schedulerTimeHeader = 'x-cloudscheduler-scheduletime';

/// Endpoint privado e sem parâmetros funcionais. Categoria, idioma e limite
/// são definidos no servidor e a identidade do Scheduler é validada pelo IAM.
export function createNewsRefreshHttp({
  onRequest,
  options,
  refreshService,
  logger = console,
}) {
  if (typeof onRequest !== 'function' ||
      !options ||
      !refreshService ||
      typeof refreshService.refresh !== 'function') {
    throw new TypeError('news_http_dependencies_invalid');
  }
  return onRequest(options, async (request, response) => {
    if (request.method !== 'POST') {
      return response.status(405).json({ error: 'method_not_allowed' });
    }
    if (request.body != null &&
        (typeof request.body !== 'object' ||
          Array.isArray(request.body) ||
          Object.keys(request.body).length !== 0)) {
      return response.status(400).json({ error: 'invalid_request' });
    }
    const scheduleTime = requireScheduleTime(request.get?.(schedulerTimeHeader));
    if (scheduleTime === null) {
      logger.warn({ event: 'news_refresh_rejected', code: 'news_schedule_time_invalid' });
      return response.status(400).json({ error: 'news_schedule_time_invalid' });
    }
    try {
      const feeds = await refreshService.refresh({
        requestId: requestIdFor(scheduleTime),
      });
      const articleCount = feeds.reduce(
        (sum, feed) => sum + (Array.isArray(feed?.articles) ? feed.articles.length : 0),
        0,
      );
      logger.info({
        event: 'news_refresh_http_completed',
        categoryCount: feeds.length,
        articleCount,
      });
      return response.status(200).json({
        categoryCount: feeds.length,
        articleCount,
      });
    } catch (error) {
      const code = safeErrorCode(error);
      const status = statusFor(code);
      logger.warn({ event: 'news_refresh_rejected', code, status });
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
  return typeof error?.code === 'string' && /^news_[a-z0-9_]{3,80}$/.test(error.code)
    ? error.code
    : 'news_refresh_failed';
}

function statusFor(code) {
  if (code === 'news_daily_limit_reached') return 429;
  if (code === 'news_provider_not_configured') return 503;
  if (code.startsWith('news_provider_') || code.startsWith('news_gateway_')) return 502;
  if (code === 'news_refresh_leased' || code === 'news_refresh_circuit_open') return 409;
  return 500;
}
