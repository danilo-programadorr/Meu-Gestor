import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const files = [
  'index.mjs',
  'src/function_options.mjs',
  'src/fail_closed_dependencies.mjs',
];
const forbidden = /(?:firebase-admin|@google-cloud|googleapis|@google\/genai|vertexai|generative-ai|openai|anthropic|secretmanager|https?:\/\/|process\.env)/iu;

for (const file of files) {
  const source = await readFile(join(root, file), 'utf8');
  if (forbidden.test(source)) throw new Error(`assistant_function_forbidden_dependency:${file}`);
}

const sharedFiles = await readdir(join(root, 'shared'));
if (!sharedFiles.includes('firebase_gen2_registration.mjs')) {
  throw new Error('assistant_function_shared_contract_missing');
}
console.log('Assistant Functions structural check passed.');
