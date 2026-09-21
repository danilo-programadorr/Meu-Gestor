/**
 * Intenção: verificar sem rede o corpo HTTP produzido pelo SDK Vertex fixado,
 * inclusive a precedência entre configuração do modelo e da chamada.
 */
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

import { ASSISTANT_VERTEX_RESPONSE_SCHEMA } from '../shared/index.mjs';

const require = createRequire(import.meta.url);
const { generateContent } = require('../node_modules/@google-cloud/vertexai/build/src/functions/generate_content.js');

test('SDK serializa MIME e schema do modelo quando a chamada não os sobrescreve', async (t) => {
  let capturedUrl;
  let capturedBody;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    capturedUrl = String(url);
    capturedBody = JSON.parse(options.body);
    return new Response(JSON.stringify({
      candidates: [{
        index: 0,
        finishReason: 'STOP',
        content: { role: 'model', parts: [{ text: '{"schemaVersion":1}' }] },
      }],
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  });

  const generationConfig = {
    temperature: 0,
    maxOutputTokens: 800,
    responseMimeType: 'application/json',
    responseSchema: ASSISTANT_VERTEX_RESPONSE_SCHEMA,
  };
  await generateContent(
    'global',
    'projects/synthetic-project/locations/global/publishers/google/models/gemini-2.5-flash',
    Promise.resolve('synthetic-access-token'),
    { contents: [{ role: 'user', parts: [{ text: 'synthetic prompt' }] }] },
    'aiplatform.googleapis.com',
    generationConfig,
  );

  assert.match(capturedUrl, /^https:\/\/aiplatform\.googleapis\.com\/v1\//u);
  assert.deepEqual(capturedBody.generationConfig, generationConfig);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.deepEqual(Object.keys(capturedBody.generationConfig.responseSchema.properties).sort(), [
    'answer', 'assertions', 'missingData', 'schemaVersion', 'status',
  ]);
  assert.equal('disclaimer' in capturedBody.generationConfig.responseSchema.properties, false);
});
