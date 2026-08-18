/// A identidade é fornecida por parâmetro do ambiente no deploy futuro; este
/// repositório não contém e-mail de conta de serviço nem identificador de
/// projeto. O Emulator aceita a ausência para testes locais; fora dele, a
/// borda falha ao carregar sem a identidade explicitamente parametrizada.
const runtimeServiceAccount = process.env.PRIVACY_RUNTIME_SERVICE_ACCOUNT;
if (!runtimeServiceAccount && process.env.FUNCTIONS_EMULATOR !== 'true') {
  throw new Error('privacy_runtime_service_account_required');
}

export const PRIVACY_FUNCTION_OPTIONS = Object.freeze({
  region: 'southamerica-east1',
  ...(runtimeServiceAccount ? { serviceAccount: runtimeServiceAccount } : {}),
  memory: '256MiB',
  timeoutSeconds: 60,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  enforceAppCheck: true,
});
