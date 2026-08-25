import { cp, readdir, rm, stat } from 'node:fs/promises';
import { dirname, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const functionRoot = resolve(scriptDirectory, '..');
const repositoryBackend = resolve(functionRoot, '..', '..');
const source = resolve(repositoryBackend, 'subscriptions', 'src');
const generatedRoot = resolve(functionRoot, '.generated');
const target = resolve(generatedRoot, 'subscriptions', 'src');

assertInside(functionRoot, generatedRoot);
assertInside(generatedRoot, target);
await requireDirectory(source);

await rm(resolve(generatedRoot, 'subscriptions'), {
  recursive: true,
  force: true,
});
await cp(source, target, {
  recursive: true,
  errorOnExist: false,
  force: true,
});

for (const requiredFile of [
  'closed_test_grants.mjs',
  'errors.mjs',
  'mapper.mjs',
  'rtdn.mjs',
]) {
  const file = resolve(target, requiredFile);
  assertInside(target, file);
  const information = await stat(file);
  if (!information.isFile()) throw new Error('shared_subscription_file_missing');
}

const generatedFiles = await readdir(target);
if (!generatedFiles.some((name) => name.endsWith('.mjs'))) {
  throw new Error('shared_subscription_artifact_empty');
}

function assertInside(parent, child) {
  const location = relative(parent, child);
  if (location === '' || location.startsWith(`..${sep}`) || location === '..') {
    throw new Error('unsafe_generated_subscription_path');
  }
}

async function requireDirectory(directory) {
  const information = await stat(directory);
  if (!information.isDirectory()) throw new Error('shared_subscription_source_missing');
}
