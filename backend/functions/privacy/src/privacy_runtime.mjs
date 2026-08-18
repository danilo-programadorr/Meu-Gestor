import { PrivacyOperationProcessor } from '../../../privacy/src/processor.mjs';

/// A única composição permitida para o núcleo de privacidade. Storage,
/// Firestore/Admin e relógio chegam por injeção; nenhuma decisão de domínio é
/// duplicada na borda Gen 2.
export function createPrivacyRuntime({ storage, adapters, receiptIdGenerator, operationIdGenerator, batchSize }) {
  if (!storage || !adapters || !receiptIdGenerator) {
    throw new TypeError('Invalid privacy runtime dependencies.');
  }
  return new PrivacyOperationProcessor({
    storage,
    clock: adapters.clock,
    sessionGateway: adapters.sessionGateway,
    authGateway: adapters.authGateway,
    receiptIdGenerator,
    operationIdGenerator,
    batchSize,
  });
}
