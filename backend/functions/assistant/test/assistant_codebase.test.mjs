import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

import {
  ASSISTANT_FUNCTION_OPTIONS,
  assistantKillSwitchActive,
  assistantProviderFeatureEnabled,
  assistantRuntimeServiceAccount,
} from '../src/function_options.mjs';
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
  assert.deepEqual(manifest.dependencies, {
    '@google-cloud/vertexai': '1.12.0',
    'firebase-functions': '7.3.2',
  });
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
  assert.equal(assistantProviderFeatureEnabled.value(), false);
  assert.equal(assistantKillSwitchActive.value(), true);
});

test('adapters sem banco falham fechados antes de qualquer leitura futura', async () => {
  const dependencies = createFailClosedAssistantDependencies({
    HttpsError: FakeHttpsError,
    providerGateway: { generate: async () => { throw new Error('provider_must_not_run'); } },
  });
  for (const action of [dependencies.authorizationReader, dependencies.contextReader, dependencies.usageReader, dependencies.ledger.reserve]) {
    await assert.rejects(action(), (error) => error.code === 'failed-precondition');
  }
});

test('artefato não contém Admin, Firestore, URL externa, segredo ou acesso ao banco padrão', async () => {
  const sources = await Promise.all([
    readFile(new URL('../index.mjs', import.meta.url), 'utf8'),
    readFile(new URL('../src/function_options.mjs', import.meta.url), 'utf8'),
    readFile(new URL('../src/fail_closed_dependencies.mjs', import.meta.url), 'utf8'),
  ]);
  const source = sources.join('\n');
  assert.doesNotMatch(source, /from\s+['"]firebase-admin|firebase-admin\/firestore|getFirestore\(/iu);
  assert.doesNotMatch(source, /https?:\/\//iu);
  assert.doesNotMatch(source, /secretmanager|api[_-]?key|private[_-]?key|process\.env/iu);
});

test('ponte Vertex é dinâmica, genérica e não abre cliente com circuito desligado', async () => {
  const source = await readFile(
    new URL('../../../assistant/src/vertex_runtime_gateway.mjs', import.meta.url),
    'utf8',
  );
  assert.match(source, /await import\('@google-cloud\/vertexai'\)/u);
  assert.match(source, /process\.env\.GCLOUD_PROJECT/u);
  assert.doesNotMatch(source, /firebase-admin|getFirestore\(|https?:\/\/|secretmanager|console\./iu);
  assert.doesNotMatch(source, /meu-gestor-financeiro|AIza|private[_-]?key|serviceAccountKey/iu);
});

test('roteiro development separa inspeção, deploy fechado, ativação bloqueada e APK local', async () => {
  const source = await readFile(new URL('../scripts/deploy-development.ps1', import.meta.url), 'utf8');
  for (const phase of ['Inspect', 'DeploySafeCircuit', 'ActivateDevelopment', 'BuildDevelopmentApk']) {
    assert.match(source, new RegExp(`'${phase}'`, 'u'));
  }
  assert.match(source, /functions:assistant:assistRemoteV1/u);
  assert.match(source, /ASSISTANT_REAL_PROVIDER_ENABLED=false/u);
  assert.match(source, /ASSISTANT_KILL_SWITCH_DISABLED=false/u);
  assert.match(source, /ASSISTANT_REMOTE_ENABLED=true/u);
  assert.match(source, /ativação global bloqueada/iu);
  assert.match(source, /effectiveMinInstanceCount\s*=\s*if\s*\(\$null -eq \$service\.minInstanceCount\)\s*\{\s*0\s*\}/u);
  assert.match(source, /configuração remota divergiu em:/iu);
  assert.match(source, /'região'/u);
  assert.match(source, /'identidade runtime'/u);
  assert.match(source, /'máximo de instâncias'/u);
  assert.doesNotMatch(source, /AIza|private[_-]?key|secretmanager|login:ci/iu);
});
