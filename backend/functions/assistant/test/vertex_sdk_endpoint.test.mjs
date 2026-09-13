/**
 * Intenção: prova sem rede qual host o SDK instalado constrói para a
 * localidade global e preserva a seleção regional nativa.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import { VertexAI } from '@google-cloud/vertexai';
import {
  assistantVertexClientConfiguration,
} from '../shared/index.mjs';

const captureSdkHost = async (location) => {
  const configuration = assistantVertexClientConfiguration({
    projectId: 'synthetic-project',
    location,
  });
  const authClient = Object.freeze({
    getAccessToken: async () => Object.freeze({ token: 'synthetic-offline-placeholder' }),
  });
  const client = new VertexAI({
    project: configuration.projectId,
    location: configuration.location,
    ...(configuration.apiEndpoint ? { apiEndpoint: configuration.apiEndpoint } : {}),
    googleAuthOptions: { authClient },
  });
  const originalFetch = globalThis.fetch;
  let constructedHost;
  globalThis.fetch = async (input) => {
    constructedHost = new URL(typeof input === 'string' ? input : input.url).hostname;
    throw new Error('offline_network_barrier');
  };
  try {
    await client.getGenerativeModel({ model: 'gemini-2.5-flash' }).generateContent({
      contents: [{ role: 'user', parts: [{ text: 'synthetic endpoint check' }] }],
    });
  } catch {
    // O SDK encapsula a barreira; o host capturado comprova que não houve rede.
  } finally {
    globalThis.fetch = originalFetch;
  }
  return constructedHost;
};

test('SDK constrói o endpoint oficial para global sem alcançar a rede', async () => {
  assert.equal(await captureSdkHost('global'), 'aiplatform.googleapis.com');
});

test('SDK preserva o endpoint derivado para localidades regionais', async () => {
  assert.equal(await captureSdkHost('southamerica-east1'), 'southamerica-east1-aiplatform.googleapis.com');
});
