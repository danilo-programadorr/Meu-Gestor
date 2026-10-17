const REQUEST_FIELDS = Object.freeze(['query']);

/// Borda autenticada do autocomplete. Erros do provedor são reduzidos a
/// classes seguras; consulta, identidade e resposta externa nunca são logadas.
export function createAssetSearchCallable({ onCall, HttpsError, options, directory, logger = console }) {
  if (typeof onCall !== 'function' || typeof HttpsError !== 'function' ||
      !options || !directory || typeof directory.search !== 'function') {
    throw new TypeError('asset_search_callable_invalid_dependencies');
  }
  return onCall(options, async (request) => {
    if (typeof request?.auth?.uid !== 'string') {
      throw new HttpsError('unauthenticated', 'Autenticação obrigatória.');
    }
    if (request.auth.token?.email_verified !== true) {
      throw new HttpsError('permission-denied', 'E-mail verificado obrigatório.');
    }
    if (!request.app) {
      throw new HttpsError('failed-precondition', 'App Check obrigatório.');
    }
    if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data) ||
        Object.keys(request.data).sort().join(',') !== REQUEST_FIELDS.join(',')) {
      throw new HttpsError('invalid-argument', 'Contrato de busca inválido.');
    }
    try {
      const results = await directory.search(request.data.query);
      logger.info('asset_directory_search', { outcome: 'passed', resultCount: results.length });
      return Object.freeze({ schemaVersion: 1, results });
    } catch (error) {
      const reason = allowedReason(error?.code);
      logger.warn('asset_directory_search', { outcome: 'failed', reason });
      const code = reason === 'invalid_query' ? 'invalid-argument' :
        reason === 'timeout' ? 'deadline-exceeded' : 'unavailable';
      throw new HttpsError(code, 'Catálogo de ativos indisponível.');
    }
  });
}

function allowedReason(code) {
  if (code === 'asset_directory_invalid_query') return 'invalid_query';
  if (code === 'asset_directory_timeout') return 'timeout';
  if (code === 'asset_directory_not_configured') return 'not_configured';
  if (code === 'asset_directory_invalid_payload') return 'invalid_payload';
  return 'provider_unavailable';
}
