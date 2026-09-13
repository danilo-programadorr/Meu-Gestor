import { readFile, readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const sourceDirectory = fileURLToPath(new URL('../src/', import.meta.url));
const ownerScopedFirestoreContextFile = 'owner_scoped_firestore_context.mjs';
const approvedFirestoreRestOrigin = 'https://firestore.googleapis.com/';
const vertexRuntimeGatewayFile = 'vertex_runtime_gateway.mjs';
const approvedVertexRuntimeDependency = '@google-cloud/vertexai';
const approvedVertexRuntimeProjectId = 'process.env.GCLOUD_PROJECT';
const approvedVertexGlobalEndpoint = 'aiplatform.googleapis.com';
// Rótulos de modelo são seguros; SDK, endpoint e projeto permanecem restritos
// exclusivamente ao gateway aprovado e auditado.
const forbidden = /(?:firebase-admin|firebase-functions|@google-cloud|googleapis|@google\/genai|generative-ai|openai|anthropic|\bsecretmanager(?:\b|client\b|service\b|config\b|secret\b|url\b|endpoint\b)|https?:\/\/|process\.env)/i;

/** Responsabilidade: permite somente fronteiras backend documentadas e literais auditados. */
export const hasForbiddenRuntimeDependency = (source, fileName = '') => {
  let sourceForCheck = source;
  if (fileName === ownerScopedFirestoreContextFile) {
    sourceForCheck = sourceForCheck.replaceAll(approvedFirestoreRestOrigin, 'approved_firestore_rest_origin/');
  }
  if (fileName === vertexRuntimeGatewayFile) {
    const vertexEndpointHosts = source.match(/[a-z0-9.-]*aiplatform\.googleapis\.com/giu) ?? [];
    if (vertexEndpointHosts.some((host) => host !== approvedVertexGlobalEndpoint)) return true;
    sourceForCheck = sourceForCheck
      .replaceAll(approvedVertexRuntimeDependency, 'approved_vertex_runtime_dependency')
      .replaceAll(approvedVertexRuntimeProjectId, 'approved_vertex_runtime_project_id')
      .replaceAll(approvedVertexGlobalEndpoint, 'approved_vertex_global_endpoint');
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
