/**
 * Intenção: provar sem rede qual host o Google Gen AI SDK instalado constrói
 * para global e para uma localidade regional.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import { GoogleGenAI } from '@google/genai';
import { assistantVertexClientConfiguration } from '../shared/index.mjs';

const captureSdkHost = async (location, t) => {
  const configuration = assistantVertexClientConfiguration({
    projectId: 'synthetic-project',
    location,
  });
  const authClient = Object.freeze({
    getRequestHeaders: async () => new Headers({ authorization: 'Bearer synthetic-offline-placeholder' }),
  });
  const client = new GoogleGenAI({
    vertexai: true,
    project: configuration.projectId,
    location: configuration.location,
    apiVersion: configuration.apiVersion,
    googleAuthOptions: { authClient },
    httpOptions: {
      ...(configuration.apiEndpoint
        ? { baseUrl: `https://${configuration.apiEndpoint}` }
        : {}),
      retryOptions: { attempts: 1 },
    },
  });
  let constructedUrl;
  t.mock.method(globalThis, 'fetch', async (input) => {
    constructedUrl = new URL(typeof input === 'string' ? input : input.url);
    return new Response(JSON.stringify({ candidates: [] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  });
  await client.models.generateContent({
    model: 'gemini-3.8-flash',
    contents: [{ role: 'user', parts: [{ text: 'synthetic endpoint check' }] }],
  });
  return constructedUrl;
};

test('SDK constrói o endpoint oficial para global sem alcançar a rede', async (t) => {
  const url = await captureSdkHost('global', t);
  assert.equal(url.hostname, 'aiplatform.googleapis.com');
  assert.match(url.pathname, /^\/v1\//u);
});

test('SDK preserva o endpoint derivado para localidades regionais', async (t) => {
  const url = await captureSdkHost('southamerica-east1', t);
  assert.equal(url.hostname, 'southamerica-east1-aiplatform.googleapis.com');
  assert.match(url.pathname, /^\/v1\//u);
});
