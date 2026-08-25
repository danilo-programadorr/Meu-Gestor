import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourceDirectory = fileURLToPath(new URL('../src/', import.meta.url));
const files = (await readdir(sourceDirectory)).filter((file) => file.endsWith('.mjs'));
const forbidden = /(?:firebase-admin|firebase-functions|@google-cloud|googleapis|openai|gemini|anthropic|secretmanager|https?:\/\/|process\.env)/i;
for (const file of files) {
  const source = await readFile(join(sourceDirectory, file), 'utf8');
  if (forbidden.test(source)) throw new Error(`assistant_forbidden_runtime_dependency:${file}`);
}
console.log('Assistant contract structural check passed.');
