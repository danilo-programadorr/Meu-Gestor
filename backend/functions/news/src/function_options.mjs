import { defineSecret, defineString } from 'firebase-functions/params';

/// Parâmetros exclusivos de runtime. Nenhuma chave do Marketaux entra no
/// código, no APK, no Firestore ou em arquivo de ambiente versionado.
export const newsRuntimeServiceAccount = defineString('NEWS_RUNTIME_SERVICE_ACCOUNT');
export const marketauxApiToken = defineSecret('MARKETAUX_API_TOKEN');

export const NEWS_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: newsRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  invoker: 'private',
  secrets: [marketauxApiToken],
});
