import { deny, requireExactObject, requireText } from './errors.mjs';

const FIELDS = Object.freeze(['environment', 'projectId']);

/// O vínculo ambiente/projeto é configuração local do backend. Nenhuma rota
/// de compra ou RTDN recebe ambiente confiável do cliente ou da mensagem.
export function resolveSubscriptionBackendEnvironment(configuration) {
  requireExactObject(configuration, FIELDS, 'invalid_subscription_environment_configuration');
  requireText(configuration.environment, 'invalid_subscription_environment');
  requireText(configuration.projectId, 'invalid_subscription_project_id');
  if (!['development', 'production'].includes(configuration.environment)) {
    throw deny('invalid_subscription_environment');
  }
  return Object.freeze({
    environment: configuration.environment,
    projectId: configuration.projectId,
  });
}
