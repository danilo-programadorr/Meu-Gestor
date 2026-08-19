import { onRequest } from 'firebase-functions/v2/https';

import { QUOTE_FUNCTION_OPTIONS } from './src/function_options.mjs';
import { createQuoteRefreshHttp } from './src/quote_refresh_http.mjs';

// O bootstrap development não carrega gateway nem storage. A integração real
// só poderá ser conectada após segredos, regras e ativação próprios aprovados.
const disabledRefreshService = Object.freeze({
  async refresh() {
    throw new Error('quote_refresh_not_configured');
  },
});

export const refreshDelayedMarketQuotes = createQuoteRefreshHttp({
  onRequest,
  options: QUOTE_FUNCTION_OPTIONS,
  refreshService: disabledRefreshService,
  sharedSecret: () => null,
  logger: console,
});
