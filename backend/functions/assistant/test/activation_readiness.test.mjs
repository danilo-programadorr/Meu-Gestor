/** Intenção: executa o mesmo pré-check local usado antes da ativação manual. */
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import test from 'node:test';

const run = promisify(execFile);

test('pré-check só aprova quando adaptadores reais estão conectados', async () => {
  const { stdout } = await run(process.execPath, ['scripts/assert-activation-readiness.mjs'], {
    cwd: new URL('..', import.meta.url),
  });
  assert.match(stdout, /Assistant activation adapters wired locally\./u);
});
