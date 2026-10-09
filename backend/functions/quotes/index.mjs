import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';

import { brapiApiToken, QUOTE_FUNCTION_OPTIONS } from './src/function_options.mjs';
import { createQuoteRefreshHttp } from './src/quote_refresh_http.mjs';
import { createQuoteRuntime } from './src/quote_runtime.mjs';

/// Bootstrap operacional development. A abertura deste bloco compõe somente
/// catálogo global, snapshots globais e segredo de runtime; não lê usuários.
if (getApps().length === 0) initializeApp();
const runtime = createQuoteRuntime({
  firestore: getFirestore(),
  Timestamp,
  token: () => brapiApiToken.value(),
  logger: console,
});

export const refreshDelayedMarketQuotes = createQuoteRefreshHttp({
  onRequest,
  options: QUOTE_FUNCTION_OPTIONS,
  catalog: runtime.catalog,
  refreshService: runtime.refreshService,
  logger: console,
});
