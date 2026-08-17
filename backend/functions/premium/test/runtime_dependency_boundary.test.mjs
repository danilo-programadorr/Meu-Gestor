import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const functionRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const forbiddenRuntimeModules = Object.freeze([
  'firebase-admin/storage',
  '@google-cloud/storage',
  'uuid',
  'gaxios',
  'teeny-request',
  'retry-request',
]);

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    const location = join(directory, entry.name);
    if (entry.isDirectory()) return sourceFiles(location);
    return entry.isFile() && entry.name.endsWith('.mjs') ? [location] : [];
  }));
  return files.flat();
}

function importsModule(source, moduleName) {
  const escaped = moduleName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const expression = new RegExp(
    `(?:from\\s*|import\\s*\\(|require\\s*\\()(['"])${escaped}\\1`,
    'u',
  );
  return expression.test(source);
}

test('Premium runtime does not import optional or vulnerable dependency paths', async () => {
  const sources = await sourceFiles(join(functionRoot, 'src'));
  sources.push(join(functionRoot, 'index.mjs'));

  for (const sourceFile of sources) {
    const source = await readFile(sourceFile, 'utf8');
    for (const forbiddenModule of forbiddenRuntimeModules) {
      assert.equal(
        importsModule(source, forbiddenModule),
        false,
        `${sourceFile} must not import ${forbiddenModule}`,
      );
    }
  }
});
