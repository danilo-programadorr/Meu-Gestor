import { BrapiDelayedQuoteGateway } from '../shared/brapi_gateway.mjs';
import { PersistentQuoteRefreshService } from '../shared/persistent_quote_refresh_service.mjs';
import { createFirestoreQuoteCatalog } from './firestore_quote_catalog.mjs';
import { createFirestoreQuoteStorage } from './firestore_quote_storage.mjs';

/// Composição operacional única. A abertura deste bloco mantém as fronteiras
/// externas injetáveis para testes sem substituir validação, lease ou storage.
export function createQuoteRuntime({
  firestore,
  Timestamp,
  token,
  fetchImpl = globalThis.fetch,
  clock = () => new Date(),
  logger = console,
}) {
  const storage = createFirestoreQuoteStorage({ firestore, Timestamp });
  const gateway = new BrapiDelayedQuoteGateway({ fetchImpl, token, clock });
  const catalog = createFirestoreQuoteCatalog({ firestore, logger });
  const refreshService = new PersistentQuoteRefreshService({ storage, gateway, clock, logger });
  return Object.freeze({ catalog, refreshService, storage, gateway });
}
