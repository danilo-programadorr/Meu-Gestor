/// Worker interno: somente documentos criados pelo backend chegam a esta
/// entrada. UID e operação são lidos do caminho/evento, nunca do aplicativo.
export function createPrivacyOperationWorker({ onDocumentWritten, options, processor, logger = console }) {
  if (typeof onDocumentWritten !== 'function' || !options ||
      !processor || typeof processor.process !== 'function') {
    throw new TypeError('privacy_worker_dependencies_invalid');
  }
  return onDocumentWritten({
    ...options,
    document: 'users/{ownerId}/privacyOperations/current',
  }, async (event) => {
    const ownerId = event?.params?.ownerId;
    const after = event?.data?.after;
    if (!after?.exists) return;
    const data = after.data();
    if (data?.state === 'prepared' || data?.state === 'failed') return;
    try {
      const result = await processor.process({ ownerId, operationId: data?.operationId });
      logger.info('privacy_worker_transition', {
        stage: 'processed',
        state: result?.state,
      });
    } catch (_) {
      // A plataforma recebe somente uma falha enumerada e repetível. Erros do
      // SDK podem conter caminhos owner-scoped e nunca atravessam esta borda.
      logger.info('privacy_worker_transition', {
        stage: 'failed',
        state: 'retryable',
      });
      throw new Error('privacy_worker_retryable_failure');
    }
  });
}
