/**
 * Responsabilidade: fornece portas que recusam leitura ou escrita até existir
 * uma implementação server-side explicitamente autorizada e auditada.
 */
export function createFailClosedAssistantDependencies({ HttpsError, providerGateway, ledger = undefined, authorizationReader = undefined, contextReader = undefined }) {
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
  const failClosedLedger = Object.freeze({ reserve: unavailable, confirm: unavailable });
  if (ledger !== undefined && (!ledger || typeof ledger.reserve !== 'function' || typeof ledger.confirm !== 'function')) {
    throw new TypeError('assistant_ledger_port_required');
  }
  if (authorizationReader !== undefined && typeof authorizationReader !== 'function') throw new TypeError('assistant_authorization_reader_required');
  if (contextReader !== undefined && typeof contextReader !== 'function') throw new TypeError('assistant_context_reader_required');

  return Object.freeze({
    authorizationReader: authorizationReader ?? unavailable,
    contextReader: contextReader ?? unavailable,
    usageReader: unavailable,
    ledger: ledger ?? failClosedLedger,
    providerGateway,
  });
}
