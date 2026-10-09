/**
 * Responsabilidade: empacota somente os contratos ESM versionados de cotações
 * exigidos pela Function, sem copiar dependências, credenciais ou configuração.
 */
import { cp, mkdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const source = fileURLToPath(new URL('../../../quotes/src/', import.meta.url));
const destination = fileURLToPath(new URL('../shared/', import.meta.url));

await rm(destination, { recursive: true, force: true });
await mkdir(destination, { recursive: true });
await cp(source, destination, {
  recursive: true,
  filter: (path) => path.endsWith('.mjs') || !path.includes('.'),
});
console.log('Quotes shared contract prepared.');
