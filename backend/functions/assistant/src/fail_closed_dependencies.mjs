export function createFailClosedAssistantDependencies({ HttpsError }) {
  if (typeof HttpsError !== 'function') {
    throw new TypeError('assistant_https_error_required');
  }

  const unavailable = async () => {
    throw new HttpsError('failed-precondition', 'Assistente indisponível com segurança.');
  };

  return Object.freeze({
    authorizationReader: unavailable,
    contextReader: unavailable,
    usageReader: unavailable,
    ledger: Object.freeze({ reserve: unavailable, confirm: unavailable }),
  });
}
