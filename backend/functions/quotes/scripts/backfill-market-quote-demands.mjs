/**
 * Responsabilidade: materializa uma vez as demandas dos ativos development
 * anteriores ao trigger, sem imprimir identidade, carteira ou conteúdo.
 * Exige --apply e o projeto exato; nunca cria credencial ou chave local.
 */
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import { createFirestoreQuoteCatalogSync } from '../src/firestore_quote_catalog_sync.mjs';

const expectedProject = 'meu-gestor-financeiro-dev';
const apply = process.argv.includes('--apply');
const projectArgument = process.argv.find((value) => value.startsWith('--project='));
const projectId = projectArgument?.slice('--project='.length);
if (!apply || projectId !== expectedProject) {
  process.stderr.write('Uso seguro: npm run backfill:catalog -- --apply --project=meu-gestor-financeiro-dev\n');
  process.exitCode = 2;
} else {
  if (getApps().length === 0) initializeApp({ projectId });
  const firestore = getFirestore();
  const assets = await firestore.collectionGroup('investmentAssets').get();
  const sync = createFirestoreQuoteCatalogSync({
    firestore,
    Timestamp,
    logger: { info() {} },
  });
  let processed = 0;
  for (const document of assets.docs) {
    const userDocument = document.ref.parent.parent;
    const userId = userDocument?.id;
    if (typeof userId !== 'string' || userId.length === 0) {
      throw new Error('quote_backfill_invalid_asset_path');
    }
    await sync({
      params: { userId, assetId: document.id },
      data: { before: { exists: false }, after: document },
      time: new Date().toISOString(),
    });
    processed += 1;
  }
  process.stdout.write(`Backfill concluído com ${processed} ativos processados.\n`);
}
