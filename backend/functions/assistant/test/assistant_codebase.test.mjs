import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

import {
  ASSISTANT_FUNCTION_OPTIONS,
  assistantRuntimeServiceAccount,
} from '../src/function_options.mjs';
import { createFailClosedAssistantDependencies } from '../src/fail_closed_dependencies.mjs';
import { createAssistantRuntimeLedger } from '../src/runtime_ledger.mjs';

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
    'google-auth-library': '10.9.1',
  });
});

test('runtime identity é parâmetro sem valor versionado e opções são conservadoras', async () => {
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
  const entryPoint = await readFile(new URL('../index.mjs', import.meta.url), 'utf8');
  assert.match(entryPoint, /runtimeControlsReader: readAssistantRuntimeControls/u);
  assert.doesNotMatch(entryPoint, /\.value\(\)/u);
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
    readFile(new URL('../src/runtime_adapters.mjs', import.meta.url), 'utf8'),
  ]);
  const source = sources.join('\n');
  assert.doesNotMatch(source, /from\s+['"]firebase-admin|firebase-admin\/firestore|getFirestore\(/iu);
  assert.doesNotMatch(source, /https?:\/\//iu);
  assert.doesNotMatch(source, /secretmanager|api[_-]?key|private[_-]?key|process\.env/iu);
});

test('adaptadores runtime usam somente bearer próprio para o banco padrão', async () => {
  const source = await readFile(new URL('../src/runtime_adapters.mjs', import.meta.url), 'utf8');
  assert.match(source, /OwnerScopedFirestoreRestTransport/u);
  assert.match(source, /getOwnAuthorizationDocument/u);
  assert.doesNotMatch(source, /firebase-admin|getFirestore\(|GOOGLE_APPLICATION_CREDENTIALS|metadata\.google|\(default\)/iu);
});

test('ledger usa somente ADC para o banco nomeado e mantém a fronteira do banco padrão fechada', async () => {
  const source = await readFile(new URL('../src/named_database_ledger_store.mjs', import.meta.url), 'utf8');
  assert.match(source, /from\s+['"]google-auth-library['"]/u);
  assert.match(source, /assistant-controls-dev/u);
  assert.match(source, /https:\/\/firestore\.googleapis\.com\//u);
  assert.doesNotMatch(source, /firebase-admin|firebase-admin\/firestore|getFirestore\(|\(default\)|GOOGLE_APPLICATION_CREDENTIALS|metadata\.google\/internal/iu);
});

test('composição runtime usa a porta ADC do ledger sem abrir o provedor', () => {
  const ledger = createAssistantRuntimeLedger({
    store: { runTransaction: async () => { throw new Error('ledger_not_called_in_this_test'); } },
  });
  assert.equal(typeof ledger.reserve, 'function');
  assert.equal(typeof ledger.confirm, 'function');
  const dependencies = createFailClosedAssistantDependencies({
    HttpsError: FakeHttpsError,
    ledger,
    providerGateway: { generate: async () => { throw new Error('provider_must_not_run'); } },
  });
  assert.equal(dependencies.ledger, ledger);
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

test('roteiro development separa inspeção, deploy fechado, ativação confirmada e APK local', async () => {
  const source = await readFile(new URL('../scripts/deploy-development.ps1', import.meta.url), 'utf8');
  for (const phase of ['Inspect', 'DeploySafeCircuit', 'ActivateDevelopment', 'BuildDevelopmentApk']) {
    assert.match(source, new RegExp(`'${phase}'`, 'u'));
  }
  assert.match(source, /functions:assistant:assistRemoteV1/u);
  assert.match(source, /New-TemporaryEnvironmentFiles -ProviderEnabled \$false -KillSwitchDisabled \$false/u);
  assert.match(source, /New-TemporaryEnvironmentFiles -ProviderEnabled \$true -KillSwitchDisabled \$true/u);
  assert.match(source, /ASSISTANT_REAL_PROVIDER_ENABLED=\$providerValue/u);
  assert.match(source, /ASSISTANT_KILL_SWITCH_DISABLED=\$killSwitchValue/u);
  assert.match(source, /\.env\.\$ProjectId/u);
  assert.match(source, /WriteAllLines\(\$temporaryEnvironmentFile/u);
  assert.match(source, /WriteAllLines\(\$temporaryProjectEnvironmentFile/u);
  assert.match(source, /Remove-CreatedTemporaryEnvironmentFiles/u);
  assert.match(source, /finally\s*\{\s*Remove-CreatedTemporaryEnvironmentFiles/u);
  assert.doesNotMatch(
    source,
    /Set-Content[^\n]+\$(?:temporaryEnvironmentFile|temporaryProjectEnvironmentFile)[^\n]+NoNewline/u,
  );
  assert.match(source, /ASSISTANT_REMOTE_ENABLED=true/u);
  assert.match(source, /ativação global bloqueada/iu);
  const activationPhase = source.match(
    /'ActivateDevelopment'\s*\{([\s\S]*?)\n  \}\n  'BuildDevelopmentApk'/u,
  )?.[1];
  assert.ok(activationPhase, 'ramo ActivateDevelopment deve existir isoladamente');
  assert.match(activationPhase, /Assert-ActivationReadiness/u);
  assert.match(activationPhase, /Assert-RemoteFunctionConfiguration/u);
  assert.match(activationPhase, /Confirm-ManualAction -Phrase 'ATIVAR PROVEDOR SOMENTE EM DEVELOPMENT'/u);
  assert.match(activationPhase, /New-TemporaryEnvironmentFiles -ProviderEnabled \$true -KillSwitchDisabled \$true/u);
  assert.match(activationPhase, /finally\s*\{\s*Remove-CreatedTemporaryEnvironmentFiles/u);
  assert.match(source, /Assert-RemoteActivationConfiguration/u);
  assert.match(source, /\$environment\.ASSISTANT_REAL_PROVIDER_ENABLED -ne 'true'/u);
  assert.match(source, /\$environment\.ASSISTANT_KILL_SWITCH_DISABLED -ne 'true'/u);
  assert.doesNotMatch(source, /'ActivateDevelopment'[\s\S]{0,400}throw 'Ativação não pode prosseguir/u);
  assert.match(source, /effectiveMinInstanceCount\s*=\s*if\s*\(\$null -eq \$service\.minInstanceCount\)\s*\{\s*0\s*\}/u);
  assert.match(source, /configuração remota divergiu em:/iu);
  assert.match(source, /'região'/u);
  assert.match(source, /'identidade runtime'/u);
  assert.match(source, /'máximo de instâncias'/u);
  assert.doesNotMatch(source, /AIza|private[_-]?key|secretmanager|login:ci/iu);
});
