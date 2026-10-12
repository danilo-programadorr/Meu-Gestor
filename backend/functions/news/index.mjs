import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';

import { createNewsRuntime } from './src/news_runtime.mjs';
import { createNewsRefreshHttp } from './src/news_refresh_http.mjs';
import {
  marketauxApiToken,
  NEWS_FUNCTION_OPTIONS,
} from './src/function_options.mjs';

// Bootstrap exclusivo do feed global; não consulta usuários nem recebe
// filtros, carteiras ou identificadores enviados pelo aplicativo.
if (getApps().length === 0) initializeApp();
const runtime = createNewsRuntime({
  firestore: getFirestore(),
  Timestamp,
  apiToken: () => marketauxApiToken.value(),
  logger: console,
});

export const refreshMarketNews = createNewsRefreshHttp({
  onRequest,
  options: NEWS_FUNCTION_OPTIONS,
  refreshService: runtime.refreshService,
  logger: console,
});
