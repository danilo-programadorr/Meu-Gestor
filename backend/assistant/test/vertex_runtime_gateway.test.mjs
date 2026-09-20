import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_VERTEX_GLOBAL_API_ENDPOINT,
  ASSISTANT_VERTEX_LOCATION,
  ASSISTANT_VERTEX_PROMPT_VERSION,
  ASSISTANT_VERTEX_RESPONSE_SCHEMA,
  assistantVertexClientConfiguration,
  createVertexRuntimeGateway,
} from '../src/index.mjs';
import { AssistantContractError } from '../src/errors.mjs';

const execution = Object.freeze({
  enabled: true,
  tier: 'flash',
  providerModel: 'gemini-2.5-flash',
  fallback: 'safe_unavailable',
});

const providerRequest = Object.freeze({
  contractVersion: 'assist-remote-v1',
  message: 'Explique o resumo confirmado.',
  context: Object.freeze({
    civilPeriod: Object.freeze({ timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-10-01' }),
    facts: Object.freeze([Object.freeze({ evidenceId: 'ev_accounts_001', source: 'accounts', kind: 'moneyCentsBrl', value: 1200 })]),
  }),
});

test('desligado falha antes de carregar cliente, credencial ou rede', async () => {
  let factoryCalls = 0;
  const gateway = createVertexRuntimeGateway({
    vertexAiFactory: async () => { factoryCalls += 1; throw new Error('must_not_load'); },
  });
  await assert.rejects(
    gateway.generate({ execution, maximumCostCents: 20, providerRequest }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_provider_unavailable',
  );
  assert.equal(factoryCalls, 0);
});

test('flags são lidos no runtime do gateway, não em sua criação', async () => {
  let reads = 0;
  const gateway = createVertexRuntimeGateway({
    runtimeControlsReader: () => {
      reads += 1;
      return Object.freeze({ killSwitchActive: true, providerFeatureEnabled: false });
    },
  });
  assert.equal(reads, 0);
  await assert.rejects(
    gateway.generate({ execution, maximumCostCents: 20, providerRequest }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_provider_unavailable',
  );
  assert.equal(reads, 1);
});

test('fake local valida plano, usa Flash e devolve somente JSON estruturado', async () => {
  const calls = [];
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    clock: (() => { let now = 100; return () => (now += 25); })(),
    vertexAiFactory: async (configuration) => {
      calls.push(Object.freeze({ kind: 'factory', configuration }));
      return Object.freeze({
        getGenerativeModel: (modelConfiguration) => {
          calls.push(Object.freeze({ kind: 'model', modelConfiguration }));
          return Object.freeze({
            generateContent: async (request) => {
              calls.push(Object.freeze({ kind: 'generate', request }));
              return Object.freeze({
                response: Object.freeze({
                  candidates: [Object.freeze({
                    content: Object.freeze({
                      parts: [Object.freeze({ text: '{"schemaVersion":1,"status":"grounded","answer":"Resumo confirmado.","assertions":[],"missingData":[],"disclaimer":"Conteúdo informativo."}' })],
                    }),
                  })],
                }),
              });
            },
          });
        },
      });
    },
  });

  const result = await gateway.generate({ execution, maximumCostCents: 20, providerRequest });
  assert.equal(calls[0].configuration.location, ASSISTANT_VERTEX_LOCATION);
  assert.equal(calls[0].configuration.apiEndpoint, ASSISTANT_VERTEX_GLOBAL_API_ENDPOINT);
  assert.equal(calls[1].modelConfiguration.model, 'gemini-2.5-flash');
  assert.deepEqual(calls[1].modelConfiguration.generationConfig.responseSchema, ASSISTANT_VERTEX_RESPONSE_SCHEMA);
  assert.equal(calls[2].request.contents[0].role, 'user');
  const prompt = JSON.parse(calls[2].request.contents[0].parts[0].text);
  assert.equal(prompt.promptVersion, ASSISTANT_VERTEX_PROMPT_VERSION);
  assert.deepEqual(prompt.request, providerRequest);
  assert.ok(prompt.instructions.some((instruction) => instruction.includes('evidência')));
  assert.ok(prompt.instructions.some((instruction) => instruction.includes('moneyCentsBrl')));
  assert.ok(prompt.instructions.some((instruction) => instruction.includes('answer')));
  assert.equal(result.confirmedCostCents, 20);
  assert.equal(result.durationMs, 25);
  assert.equal(result.response.status, 'grounded');
  assert.equal('providerOutputIssue' in result, false);
});

test('saída ausente ou não JSON chega à admissão somente por código enumerado', async () => {
  for (const [candidate, expectedIssue] of [
    [{ response: { candidates: [] } }, 'provider_output_missing'],
    [{ response: { candidates: [{ content: { parts: [{ text: 'x'.repeat(20_001) }] } }] } }, 'provider_output_too_large'],
    [{ response: { candidates: [{ content: { parts: [{ text: 'não-json' }] } }] } }, 'provider_output_invalid_json'],
  ]) {
    const gateway = createVertexRuntimeGateway({
      providerFeatureEnabled: true,
      killSwitchActive: false,
      projectIdReader: () => 'synthetic-project',
      vertexAiFactory: async () => ({
        getGenerativeModel: () => ({ generateContent: async () => candidate }),
      }),
    });
    const result = await gateway.generate({ execution, maximumCostCents: 20, providerRequest });
    assert.equal(result.response, null);
    assert.equal(result.providerOutputIssue, expectedIssue);
  }
});

test('configura endpoint explícito apenas para location global', () => {
  assert.deepEqual(
    assistantVertexClientConfiguration({ projectId: 'synthetic-project', location: 'global' }),
    {
      projectId: 'synthetic-project',
      location: 'global',
      apiEndpoint: 'aiplatform.googleapis.com',
    },
  );
  assert.deepEqual(
    assistantVertexClientConfiguration({ projectId: 'synthetic-project', location: 'southamerica-east1' }),
    { projectId: 'synthetic-project', location: 'southamerica-east1' },
  );
});

test('recusa identidade, segredo ou saída não JSON antes de entregar ao chamador', async () => {
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: async () => ({
      getGenerativeModel: () => ({ generateContent: async () => ({ response: { candidates: [] } }) }),
    }),
  });
  await assert.rejects(
    gateway.generate({
      execution,
      maximumCostCents: 20,
      providerRequest: { ...providerRequest, context: { uid: 'proibido' } },
    }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_provider_request_unsafe',
  );
});
