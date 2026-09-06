/**
 * Responsabilidade: fornece portas que recusam leitura ou escrita até existir
 * uma implementação server-side explicitamente autorizada e auditada.
 */
export function createFailClosedAssistantDependencies({ HttpsError, providerGateway }) {
  if (typeof HttpsError !== 'function') {
    throw new TypeError('assistant_https_error_required');
  }
  if (!providerGateway || typeof providerGateway.generate !== 'function') {
    throw new TypeError('assistant_provider_gateway_required');
  }

  // Nenhuma porta sem adapter concreto pode degradar para acesso permissivo.
  const unavailable = async () => {
    throw new HttpsError('failed-precondition', 'Assistente indisponível com segurança.');
  };

  return Object.freeze({
    authorizationReader: unavailable,
    contextReader: unavailable,
    usageReader: unavailable,
    ledger: Object.freeze({ reserve: unavailable, confirm: unavailable }),
    providerGateway,
  });
}
