/**
 * Responsabilidade: bloqueia dependências e configurações proibidas no
 * artefato Functions antes de um deploy manual futuro.
 */
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const files = [
  'index.mjs',
  'src/function_options.mjs',
  'src/fail_closed_dependencies.mjs',
  'src/runtime_ledger.mjs',
  'src/runtime_adapters.mjs',
];
const forbidden = /(?:firebase-admin|@google-cloud|googleapis|@google\/genai|vertexai|generative-ai|openai|anthropic|secretmanager|https?:\/\/|process\.env)/iu;

for (const file of files) {
  const source = await readFile(join(root, file), 'utf8');
  if (forbidden.test(source)) throw new Error(`assistant_function_forbidden_dependency:${file}`);
}

const namedLedgerSource = await readFile(join(root, 'src/named_database_ledger_store.mjs'), 'utf8');
if (!namedLedgerSource.includes("from 'google-auth-library'")
    || !namedLedgerSource.includes('https://firestore.googleapis.com/')
    || !namedLedgerSource.includes('assistant-controls-dev')
    || /(?:firebase-admin|@google-cloud|@google\/genai|vertexai|secretmanager|\(default\)|GOOGLE_APPLICATION_CREDENTIALS|metadata\.google|process\.env|https?:\/\/(?!firestore\.googleapis\.com\/|www\.googleapis\.com\/auth\/datastore))/iu.test(namedLedgerSource)) {
  throw new Error('assistant_named_ledger_boundary_invalid');
}

const sharedFiles = await readdir(join(root, 'shared'));
if (!sharedFiles.includes('firebase_gen2_registration.mjs')) {
  throw new Error('assistant_function_shared_contract_missing');
}
console.log('Assistant Functions structural check passed.');
