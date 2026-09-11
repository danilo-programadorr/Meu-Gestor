/** Responsabilidade: prova localmente que os três adaptadores aprovados estão
 * conectados antes de o roteiro manual sequer permitir ativação development. */
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = async (relative) => readFile(join(root, relative), 'utf8');
const [entry, adapters, ledger, dependencies] = await Promise.all([
  source('index.mjs'), source('src/runtime_adapters.mjs'),
  source('src/runtime_ledger.mjs'), source('src/fail_closed_dependencies.mjs'),
]);
const required = [
  [entry, 'createAssistantRuntimeAdapters'], [entry, '...runtimeAdapters'],
  [entry, 'createAssistantRuntimeLedger'], [adapters, 'OwnerScopedFirestoreContextReader'],
  [adapters, 'getOwnAuthorizationDocument'], [adapters, 'financialPrivacyActive: !allowed'],
  [ledger, 'NamedDatabaseAssistantCostLedgerStore'], [dependencies, 'authorizationReader ?? unavailable'],
  [dependencies, 'contextReader ?? unavailable'],
];
if (required.some(([content, text]) => !content.includes(text))) {
  throw new Error('assistant_activation_adapters_not_wired');
}
console.log('Assistant activation adapters wired locally.');
