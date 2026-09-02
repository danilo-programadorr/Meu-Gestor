import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

import { ASSISTANT_FUNCTION_OPTIONS, assistantRuntimeServiceAccount } from '../src/function_options.mjs';
import { createFailClosedAssistantDependencies } from '../src/fail_closed_dependencies.mjs';

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

test('codebase assistant é exclusivo, Node 22 e aponta somente à callable prevista', async () => {
  const firebase = JSON.parse(await readFile(new URL('../../../../firebase.json', import.meta.url), 'utf8'));
  const assistant = firebase.functions.filter((entry) => entry.codebase === 'assistant');
  assert.deepEqual(assistant, [{
    source: 'backend/functions/assistant',
    codebase: 'assistant',
    runtime: 'nodejs22',
    predeploy: ['npm --prefix backend/functions/assistant run prepare:shared'],
    ignore: ['node_modules', '.git', '.codex-tmp', 'test'],
  }]);

  const manifest = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
  assert.equal(manifest.engines.node, '22');
  assert.deepEqual(manifest.dependencies, { 'firebase-functions': '7.3.2' });
});

test('runtime identity é parâmetro sem valor versionado e opções são conservadoras', () => {
  assert.equal(assistantRuntimeServiceAccount.name, 'ASSISTANT_RUNTIME_SERVICE_ACCOUNT');
  assert.deepEqual(ASSISTANT_FUNCTION_OPTIONS, {
    region: 'southamerica-east1',
    serviceAccount: assistantRuntimeServiceAccount,
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 1,
    concurrency: 1,
    enforceAppCheck: true,
  });
  assert.equal(process.env.ASSISTANT_RUNTIME_SERVICE_ACCOUNT, undefined);
});

test('adapters sem banco falham fechados antes de qualquer leitura futura', async () => {
  const dependencies = createFailClosedAssistantDependencies({ HttpsError: FakeHttpsError });
  for (const action of [dependencies.authorizationReader, dependencies.contextReader, dependencies.usageReader, dependencies.ledger.reserve]) {
    await assert.rejects(action(), (error) => error.code === 'failed-precondition');
  }
});

test('artefato não contém Admin, Firestore, Vertex, URL externa, segredo ou acesso ao banco padrão', async () => {
  const sources = await Promise.all([
    readFile(new URL('../index.mjs', import.meta.url), 'utf8'),
    readFile(new URL('../src/function_options.mjs', import.meta.url), 'utf8'),
    readFile(new URL('../src/fail_closed_dependencies.mjs', import.meta.url), 'utf8'),
  ]);
  const source = sources.join('\n');
  assert.doesNotMatch(source, /from\s+['"]firebase-admin|firebase-admin\/firestore|getFirestore\(/iu);
  assert.doesNotMatch(source, /vertex|aiplatform|https?:\/\//iu);
  assert.doesNotMatch(source, /secretmanager|api[_-]?key|private[_-]?key|process\.env/iu);
});
