/**
 * Intenção: verificar sem rede o corpo HTTP produzido pelo Google Gen AI SDK
 * fixado, incluindo schema, esforço e ausência de tentativas automáticas.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import { GoogleGenAI } from '@google/genai';
import { ASSISTANT_VERTEX_RESPONSE_SCHEMA } from '../shared/index.mjs';

const syntheticAuthClient = Object.freeze({
  getRequestHeaders: async () => new Headers({ authorization: 'Bearer synthetic-offline-placeholder' }),
});

test('SDK serializa MIME, schema e thinkingLevel na chamada unary', async (t) => {
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

  const client = new GoogleGenAI({
    vertexai: true,
    project: 'synthetic-project',
    location: 'global',
    apiVersion: 'v1',
    googleAuthOptions: { authClient: syntheticAuthClient },
    httpOptions: {
      baseUrl: 'https://aiplatform.googleapis.com',
      retryOptions: { attempts: 1 },
    },
  });
  await client.models.generateContent({
    model: 'gemini-3.8-flash',
    contents: [{ role: 'user', parts: [{ text: 'synthetic prompt' }] }],
    config: {
      maxOutputTokens: 800,
      thinkingConfig: { thinkingLevel: 'LOW', includeThoughts: false },
      responseMimeType: 'application/json',
      responseSchema: ASSISTANT_VERTEX_RESPONSE_SCHEMA,
    },
  });

  assert.match(capturedUrl, /^https:\/\/aiplatform\.googleapis\.com\/v1\//u);
  assert.match(capturedUrl, /gemini-3\.8-flash:generateContent$/u);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal('candidateCount' in capturedBody.generationConfig, false);
  assert.equal('temperature' in capturedBody.generationConfig, false);
  assert.deepEqual(capturedBody.generationConfig.thinkingConfig, {
    thinkingLevel: 'LOW',
    includeThoughts: false,
  });
  assert.deepEqual(capturedBody.generationConfig.responseSchema, ASSISTANT_VERTEX_RESPONSE_SCHEMA);
  assert.deepEqual(Object.keys(capturedBody.generationConfig.responseSchema.properties).sort(), [
    'assertions', 'clarificationCode', 'intent', 'missingData', 'schemaVersion', 'status',
  ]);
  assert.equal('disclaimer' in capturedBody.generationConfig.responseSchema.properties, false);
});
