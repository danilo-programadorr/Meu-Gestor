import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

import {
  brapiApiToken,
  QUOTE_CATALOG_SYNC_OPTIONS,
  QUOTE_FUNCTION_OPTIONS,
} from './src/function_options.mjs';
import {
  createFirestoreQuoteCatalogSync,
  createQuoteCatalogDocumentWritten,
} from './src/firestore_quote_catalog_sync.mjs';
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
const syncCatalog = createFirestoreQuoteCatalogSync({
  firestore: getFirestore(),
  Timestamp,
  logger: console,
});

export const refreshDelayedMarketQuotes = createQuoteRefreshHttp({
  onRequest,
  options: QUOTE_FUNCTION_OPTIONS,
  catalog: runtime.catalog,
  refreshService: runtime.refreshService,
  logger: console,
});

export const syncInvestmentQuoteCatalog = createQuoteCatalogDocumentWritten({
  onDocumentWritten,
  options: QUOTE_CATALOG_SYNC_OPTIONS,
  syncCatalog,
});
