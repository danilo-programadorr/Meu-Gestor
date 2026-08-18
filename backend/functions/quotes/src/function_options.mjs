import { defineSecret, defineString } from 'firebase-functions/params';

/// Valores específicos de ambiente são parâmetros de deploy, nunca valores
/// versionados. A ausência de qualquer um faz a Function falhar fechada.
export const quotesRuntimeServiceAccount = defineString('QUOTES_RUNTIME_SERVICE_ACCOUNT');
export const brapiApiToken = defineSecret('BRAPI_API_TOKEN');
export const quoteRefreshSharedSecret = defineSecret('QUOTE_REFRESH_SHARED_SECRET');

export const QUOTE_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: quotesRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  secrets: [brapiApiToken, quoteRefreshSharedSecret],
});
