/**
 * Responsabilidade: empacotar apenas os módulos ESM do domínio de notícias,
 * sem copiar configuração, cache, segredo ou dependência instalada.
 */
import { cp, mkdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const source = fileURLToPath(new URL('../../../news/src/', import.meta.url));
const destination = fileURLToPath(new URL('../shared/', import.meta.url));

await rm(destination, { recursive: true, force: true });
await mkdir(destination, { recursive: true });
await cp(source, destination, {
  recursive: true,
  filter: (path) => path.endsWith('.mjs') || !path.includes('.'),
});
console.log('News shared contract prepared.');
