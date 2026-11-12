import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const npmProjects = Object.freeze([
  '.',
  'backend/functions/assistant',
  'backend/functions/news',
  'backend/functions/privacy',
  'backend/functions/quotes',
  'backend/functions/premium',
]);
const exactVersion = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/u;
const packageName = /^(?:@[a-z0-9][a-z0-9._-]*\/)?[a-z0-9][a-z0-9._-]*$/u;

/// Bloqueia pacotes não fixados, origem fora dos registros oficiais e
/// lockfiles sem integridade. Não consulta rede nem executa scripts de pacote.
for (const directory of npmProjects) {
  const manifest = await json(`${directory}/package.json`);
  const lock = await json(`${directory}/package-lock.json`);
  if (lock.lockfileVersion !== 3 || !lock.packages || typeof lock.packages !== 'object') {
    fail(`${directory}: npm_lock_contract_invalid`);
  }
  const declared = {
    ...(manifest.dependencies ?? {}),
    ...(manifest.devDependencies ?? {}),
  };
  for (const [name, version] of Object.entries(declared)) {
    if (!packageName.test(name) || typeof version !== 'string' || !exactVersion.test(version)) {
      fail(`${directory}: dependency_not_exact:${name}`);
    }
    const installed = lock.packages[`node_modules/${name}`];
    if (!installed || installed.version !== version) {
      fail(`${directory}: dependency_lock_mismatch:${name}`);
    }
  }
  for (const [path, entry] of Object.entries(lock.packages)) {
    if (path === '') continue;
    if (typeof entry.resolved !== 'string' ||
        !entry.resolved.startsWith('https://registry.npmjs.org/')) {
      fail(`${directory}: dependency_registry_invalid:${path}`);
    }
    if (typeof entry.integrity !== 'string' || !entry.integrity.startsWith('sha512-')) {
      fail(`${directory}: dependency_integrity_missing:${path}`);
    }
  }
}

const pubLock = await readFile(resolve(root, 'pubspec.lock'), 'utf8');
const sources = [...pubLock.matchAll(/^\s{4}source:\s+(\S+)\s*$/gmu)].map((match) => match[1]);
if (sources.length === 0 || sources.some((source) => !['hosted', 'sdk'].includes(source))) {
  fail('dart_dependency_source_invalid');
}
const hostedUrls = [...pubLock.matchAll(/^\s{6}url:\s+"?([^"\s]+)"?\s*$/gmu)]
  .map((match) => match[1]);
if (hostedUrls.length === 0 || hostedUrls.some((url) => url !== 'https://pub.dev')) {
  fail('dart_dependency_registry_invalid');
}

console.log('dependency_provenance_verified');

async function json(relativePath) {
  return JSON.parse(await readFile(resolve(root, relativePath), 'utf8'));
}

function fail(code) {
  console.error(code);
  process.exit(1);
}
