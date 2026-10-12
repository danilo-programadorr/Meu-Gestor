/**
 * Responsabilidade: validar sintaxe do artefato de notícias sem depender de
 * expansão de glob do shell ou executar integração externa.
 */
import { readdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const files = ['index.mjs'];
for (const directory of ['src', 'shared']) {
  const names = await readdir(new URL(`../${directory}/`, import.meta.url));
  files.push(...names
    .filter((name) => name.endsWith('.mjs'))
    .map((name) => `${directory}/${name}`));
}
for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], {
    cwd: root,
    stdio: 'inherit',
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
