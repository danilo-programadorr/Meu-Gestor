import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';

import { BrapiDelayedQuoteGateway } from '../../quotes/src/brapi_gateway.mjs';
import { PersistentQuoteRefreshService } from '../../quotes/src/persistent_quote_refresh_service.mjs';
import { createFirestoreQuoteStorage } from './src/firestore_quote_storage.mjs';
import { QUOTE_FUNCTION_OPTIONS, brapiApiToken, quoteRefreshSharedSecret } from './src/function_options.mjs';
import { createQuoteRefreshHttp } from './src/quote_refresh_http.mjs';

if (getApps().length === 0) initializeApp();

const clock = () => new Date();
const refreshService = new PersistentQuoteRefreshService({
  storage: createFirestoreQuoteStorage({ firestore: getFirestore(), Timestamp }),
  gateway: new BrapiDelayedQuoteGateway({
    token: () => brapiApiToken.value(),
    clock,
  }),
  clock,
  logger: console,
});

export const refreshDelayedMarketQuotes = createQuoteRefreshHttp({
  onRequest,
  options: QUOTE_FUNCTION_OPTIONS,
  refreshService,
  sharedSecret: () => quoteRefreshSharedSecret.value(),
  logger: console,
});
