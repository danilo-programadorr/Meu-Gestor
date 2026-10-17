import { defineSecret, defineString } from 'firebase-functions/params';

/// Valores específicos de ambiente são parâmetros de deploy, nunca valores
/// versionados. O token é lido exclusivamente do Secret Manager pelo runtime.
export const quotesRuntimeServiceAccount = defineString('QUOTES_RUNTIME_SERVICE_ACCOUNT');
export const brapiApiToken = defineSecret('BRAPI_API_TOKEN');

export const QUOTE_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: quotesRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 180,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  invoker: 'private',
  secrets: [brapiApiToken],
});

/// O trigger não acessa segredo nem provedor; usa a mesma identidade dedicada
/// apenas para materializar demanda global opaca no Firestore.
export const QUOTE_CATALOG_SYNC_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: quotesRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
});

/// A callable é pública apenas no perímetro da plataforma; Auth, e-mail
/// verificado e App Check são validados antes de qualquer consulta à BRAPI.
export const ASSET_SEARCH_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: quotesRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 10,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 10,
  enforceAppCheck: true,
  secrets: [brapiApiToken],
});
