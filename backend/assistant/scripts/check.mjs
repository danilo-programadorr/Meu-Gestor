import { readFile, readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const sourceDirectory = fileURLToPath(new URL('../src/', import.meta.url));
const ownerScopedFirestoreContextFile = 'owner_scoped_firestore_context.mjs';
const approvedFirestoreRestOrigin = 'https://firestore.googleapis.com/';
const vertexRuntimeGatewayFile = 'vertex_runtime_gateway.mjs';
const approvedVertexRuntimeDependency = '@google-cloud/vertexai';
const approvedVertexRuntimeProjectId = 'process.env.GCLOUD_PROJECT';
// Logical model labels are safe in the local contract. SDKs, endpoints and
// runtime configuration remain forbidden until a separately approved backend.
const forbidden = /(?:firebase-admin|firebase-functions|@google-cloud|googleapis|@google\/genai|generative-ai|openai|anthropic|\bsecretmanager(?:\b|client\b|service\b|config\b|secret\b|url\b|endpoint\b)|https?:\/\/|process\.env)/i;

/** Responsabilidade: permite somente fronteiras backend documentadas e literais auditados. */
export const hasForbiddenRuntimeDependency = (source, fileName = '') => {
  let sourceForCheck = source;
  if (fileName === ownerScopedFirestoreContextFile) {
    sourceForCheck = sourceForCheck.replaceAll(approvedFirestoreRestOrigin, 'approved_firestore_rest_origin/');
  }
  if (fileName === vertexRuntimeGatewayFile) {
    sourceForCheck = sourceForCheck
      .replaceAll(approvedVertexRuntimeDependency, 'approved_vertex_runtime_dependency')
      .replaceAll(approvedVertexRuntimeProjectId, 'approved_vertex_runtime_project_id');
  }
  return forbidden.test(sourceForCheck);
};

const isDirectExecution = process.argv[1]
  && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isDirectExecution) {
  const files = (await readdir(sourceDirectory)).filter((file) => file.endsWith('.mjs'));
  for (const file of files) {
    const source = await readFile(join(sourceDirectory, file), 'utf8');
    if (hasForbiddenRuntimeDependency(source, file)) throw new Error(`assistant_forbidden_runtime_dependency:${file}`);
  }
  console.log('Assistant contract structural check passed.');
}
