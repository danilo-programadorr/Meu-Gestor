import { defineString } from 'firebase-functions/params';

/// Valores específicos de ambiente são parâmetros de deploy, nunca valores
/// versionados. Os segredos de provedor e chamada interna ainda não existem;
/// por isso, este bootstrap não os declara nem os vincula ao artefato.
export const quotesRuntimeServiceAccount = defineString('QUOTES_RUNTIME_SERVICE_ACCOUNT');

export const QUOTE_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  serviceAccount: quotesRuntimeServiceAccount,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  invoker: 'private',
});
