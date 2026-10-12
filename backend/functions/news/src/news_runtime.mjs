import { MarketauxNewsGateway } from '../shared/marketaux_gateway.mjs';
import { MarketNewsRefreshService } from '../shared/news_refresh_service.mjs';
import { createFirestoreNewsStorage } from './firestore_news_storage.mjs';

/// Composição concreta do Marketaux com armazenamento global. As fronteiras
/// externas permanecem injetáveis para testes sem substituir validações.
export function createNewsRuntime({
  firestore,
  Timestamp,
  apiToken,
  fetchImpl = globalThis.fetch,
  clock = () => new Date(),
  logger = console,
}) {
  const storage = createFirestoreNewsStorage({ firestore, Timestamp });
  const gateway = new MarketauxNewsGateway({ fetchImpl, apiToken, clock });
  const refreshService = new MarketNewsRefreshService({
    storage,
    gateway,
    clock,
    logger,
  });
  return Object.freeze({ storage, gateway, refreshService });
}
