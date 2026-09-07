import assert from 'node:assert/strict';
import test from 'node:test';

import { hasForbiddenRuntimeDependency } from '../scripts/check.mjs';

test('rótulo local de pré-requisito não é dependência Secret Manager', () => {
  assert.equal(hasForbiddenRuntimeDependency('const secretManagerValidated = true;'), false);
});

test('referência real a Secret Manager continua proibida', () => {
  assert.equal(hasForbiddenRuntimeDependency('const secretManager = createClient();'), true);
  assert.equal(hasForbiddenRuntimeDependency("import '@google-cloud/secret-manager';"), true);
});

test('origem REST oficial do Firestore só é permitida no leitor proprietário', () => {
  const firestoreOrigin = 'const endpoint = "https://firestore.googleapis.com/v1";';
  assert.equal(hasForbiddenRuntimeDependency(firestoreOrigin, 'owner_scoped_firestore_context.mjs'), false);
  assert.equal(hasForbiddenRuntimeDependency(firestoreOrigin, 'firebase_gen2_callable.mjs'), true);
});

test('qualquer outra URL permanece proibida, inclusive no leitor proprietário', () => {
  assert.equal(
    hasForbiddenRuntimeDependency('const endpoint = "https://vertex.googleapis.com/v1";', 'owner_scoped_firestore_context.mjs'),
    true,
  );
});

test('SDK Vertex e projeto runtime só são permitidos no gateway auditado', () => {
  const vertexRuntime = "const sdk = '@google-cloud/vertexai'; const project = process.env.GCLOUD_PROJECT;";
  assert.equal(hasForbiddenRuntimeDependency(vertexRuntime, 'vertex_runtime_gateway.mjs'), false);
  assert.equal(hasForbiddenRuntimeDependency(vertexRuntime, 'firebase_gen2_callable.mjs'), true);
});

test('outra variável de ambiente continua proibida no gateway Vertex', () => {
  assert.equal(
    hasForbiddenRuntimeDependency('const project = process.env.OTHER_PROJECT;', 'vertex_runtime_gateway.mjs'),
    true,
  );
});
