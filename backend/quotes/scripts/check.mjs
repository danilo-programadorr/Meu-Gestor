/**
 * Responsabilidade: valida todos os módulos provider-neutral sem depender da
 * expansão de glob do shell e sem executar rede ou carregar credenciais.
 */
import { readdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const names = await readdir(new URL('../src/', import.meta.url));
for (const name of names.filter((value) => value.endsWith('.mjs'))) {
  const result = spawnSync(process.execPath, ['--check', `src/${name}`], {
    cwd: root,
    stdio: 'inherit',
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
