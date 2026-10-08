import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_VERTEX_GLOBAL_API_ENDPOINT,
  ASSISTANT_VERTEX_LOCATION,
  ASSISTANT_VERTEX_PLAN_SCHEMA,
  ASSISTANT_VERTEX_PROMPT_VERSION,
  ASSISTANT_VERTEX_RESPONSE_SCHEMA,
  ASSISTANT_VERTEX_SPEECH_MODEL,
  ASSISTANT_VERTEX_SPEECH_VOICE,
  assistantVertexClientConfiguration,
  createVertexRuntimeGateway,
} from '../src/index.mjs';
import { AssistantContractError } from '../src/errors.mjs';

const execution = Object.freeze({
  enabled: true, tier: 'flash', providerModel: 'gemini-3.8-flash',
  thinkingLevel: 'LOW', fallback: 'safe_unavailable',
});
const proExecution = Object.freeze({ ...execution, tier: 'pro', thinkingLevel: 'MEDIUM' });
const planningExecution = Object.freeze({ ...execution, thinkingLevel: 'LOW' });
const providerRequest = Object.freeze({
  contractVersion: 'assist-remote-v1',
  message: 'Explique o resumo confirmado.',
  intentPlan: Object.freeze({
    schemaVersion: 1, status: 'ready', intent: 'financial_overview',
    clarificationCode: 'none', clarificationQuestion: '',
    periodCode: 'current_month', financialTool: 'overview',
  }),
  context: Object.freeze({
    civilPeriod: Object.freeze({ timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-10-01' }),
    facts: Object.freeze([Object.freeze({ evidenceId: 'ev_accounts_001', source: 'accounts', kind: 'moneyCentsBrl', value: 1200 })]),
  }),
});

const providerJson = (overrides = {}) => JSON.stringify({
  schemaVersion: 1,
  status: 'grounded',
  intent: 'financial_overview',
  clarificationCode: 'none',
  assertions: [{
    statement: 'Resumo confirmado.',
    evidence: {
      alias: 'ev_accounts_001', source: 'accounts',
      period: { timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-10-01' },
    },
  }],
  missingData: [],
  ...overrides,
});

const fakeGateway = ({ result, calls = [] } = {}) => createVertexRuntimeGateway({
  providerFeatureEnabled: true,
  killSwitchActive: false,
  projectIdReader: () => 'synthetic-project',
  clock: (() => { let now = 100; return () => (now += 25); })(),
  vertexAiFactory: async (configuration) => {
    calls.push({ kind: 'factory', configuration });
    return {
      models: {
        generateContent: async (request) => {
          calls.push({ kind: 'generate', request });
          return result ?? {
            candidates: [{ finishReason: 'STOP', content: { parts: [{ text: providerJson() }] } }],
          };
        },
      },
    };
  },
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

test('planeja intenção, período e ferramenta sem receber contexto financeiro', async () => {
  const calls = [];
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    clock: (() => { let now = 100; return () => (now += 10); })(),
    vertexAiFactory: async () => ({
      models: {
        generateContent: async (request) => {
          calls.push(request);
          return {
            candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({
              schemaVersion: 1,
              status: 'ready',
              intent: 'financial_overview',
              clarificationCode: 'none',
              clarificationQuestion: '',
              periodCode: 'current_month',
              financialTool: 'overview',
            }) }] } }],
          };
        },
      },
    }),
  });
  const result = await gateway.plan({
    execution: planningExecution,
    maximumCostCents: 20,
    request: { message: 'Prepare um relatório deste mês.' },
  });
  assert.equal(result.plan.periodCode, 'current_month');
  assert.equal(result.plan.financialTool, 'overview');
  assert.deepEqual(calls[0].config.responseSchema, ASSISTANT_VERTEX_PLAN_SCHEMA);
  assert.equal(calls[0].config.maxOutputTokens, 384);
  const prompt = JSON.parse(calls[0].contents[0].parts[0].text);
  assert.equal('context' in prompt.request, false);
  assert.ok(prompt.instructions.some((item) => item.includes('até três turnos anteriores')));
  assert.ok(prompt.instructions.some((item) => item.includes('sem exigir frases predefinidas')));
  assert.doesNotMatch(JSON.stringify(prompt), /moneyCentsBrl|evidenceId/u);
});

test('planejador conhece a identidade Luma sem lista rígida de frases', async () => {
  const calls = [];
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: async () => ({
      models: {
        generateContent: async (request) => {
          calls.push(request);
          return {
            candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({
              schemaVersion: 1,
              status: 'clarification_required',
              intent: 'unknown',
              clarificationCode: 'social_conversation',
              clarificationQuestion: 'Eu sou a Luma, sua assistente financeira. Como posso ajudar você hoje?',
              periodCode: 'none',
              financialTool: 'none',
            }) }] } }],
          };
        },
      },
    }),
  });

  const result = await gateway.plan({
    execution: planningExecution,
    maximumCostCents: 20,
    request: { message: 'Olá, tudo bem? Qual é o seu nome?' },
  });

  assert.equal(result.plan.clarificationCode, 'social_conversation');
  assert.match(result.plan.clarificationQuestion, /Luma/u);
  const prompt = JSON.parse(calls[0].contents[0].parts[0].text);
  assert.ok(prompt.instructions.some((item) => item.includes('Você é Luma')));
  assert.ok(prompt.instructions.some((item) => item.includes('o que você faz')));
  assert.ok(prompt.instructions.some((item) => item.includes('semanticamente')));
});

test('planejamento ambíguo pede esclarecimento sem selecionar leitor', async () => {
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: async () => ({
      models: {
        generateContent: async () => ({
          candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({
            schemaVersion: 1,
            status: 'clarification_required',
            intent: 'financial_overview',
            clarificationCode: 'period_required',
            clarificationQuestion: 'Você quer o relatório deste mês ou do mês anterior?',
            periodCode: 'none',
            financialTool: 'none',
          }) }] } }],
        }),
      },
    }),
  });
  const result = await gateway.plan({
    execution: planningExecution,
    maximumCostCents: 20,
    request: { message: 'Prepare um relatório.' },
  });
  assert.equal(result.plan.status, 'clarification_required');
  assert.equal(result.plan.financialTool, 'none');
  assert.equal(
    result.plan.clarificationQuestion,
    'Você quer o relatório deste mês ou do mês anterior?',
  );
});

test('planejador admite listagem livre de nomes e tickers como intenção própria', async () => {
  const calls = [];
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: async () => ({
      models: {
        generateContent: async (request) => {
          calls.push(request);
          return {
            candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({
              schemaVersion: 1,
              status: 'ready',
              intent: 'investment_assets',
              clarificationCode: 'none',
              clarificationQuestion: '',
              periodCode: 'today',
              financialTool: 'investment_assets',
            }) }] } }],
          };
        },
      },
    }),
  });

  const result = await gateway.plan({
    execution: planningExecution,
    maximumCostCents: 20,
    request: { message: 'Quais são os nomes das coisas em que investi?' },
  });

  assert.equal(result.plan.intent, 'investment_assets');
  assert.equal(result.plan.financialTool, 'investment_assets');
  const prompt = JSON.parse(calls[0].contents[0].parts[0].text);
  assert.ok(prompt.instructions.some((item) => item.includes('nomes ou seus tickers')));
  assert.ok(ASSISTANT_VERTEX_PLAN_SCHEMA.properties.intent.enum.includes('investment_assets'));
});

test('serializa Gemini 3.8 Flash, esforço baixo e contrato estruturado completo', async () => {
  const calls = [];
  const result = await fakeGateway({ calls }).generate({ execution, maximumCostCents: 20, providerRequest });
  assert.deepEqual(calls[0].configuration, {
    projectId: 'synthetic-project', location: ASSISTANT_VERTEX_LOCATION,
    apiVersion: 'v1',
    apiEndpoint: ASSISTANT_VERTEX_GLOBAL_API_ENDPOINT,
  });
  const request = calls[1].request;
  assert.equal(request.model, 'gemini-3.8-flash');
  assert.deepEqual(request.config.thinkingConfig, { thinkingLevel: 'LOW', includeThoughts: false });
  assert.equal(request.config.responseMimeType, 'application/json');
  assert.deepEqual(request.config.responseSchema, ASSISTANT_VERTEX_RESPONSE_SCHEMA);
  assert.equal('candidateCount' in request.config, false);
  assert.equal('temperature' in request.config, false);
  assert.deepEqual(Object.keys(ASSISTANT_VERTEX_RESPONSE_SCHEMA.properties).sort(), [
    'assertions', 'clarificationCode', 'intent', 'missingData', 'schemaVersion', 'status',
  ]);
  assert.deepEqual(Object.keys(ASSISTANT_VERTEX_PLAN_SCHEMA.properties).sort(), [
    'clarificationCode', 'clarificationQuestion', 'financialTool', 'intent',
    'periodCode', 'schemaVersion', 'status',
  ]);
  const prompt = JSON.parse(request.contents[0].parts[0].text);
  assert.ok(prompt.instructions.some((item) => item.includes('informal e descontraído')));
  assert.ok(prompt.instructions.some((item) => item.includes('não use bordões')));
  assert.ok(prompt.instructions.some((item) => item.includes('pergunta curta relacionada')));
  assert.equal(prompt.promptVersion, ASSISTANT_VERTEX_PROMPT_VERSION);
  assert.deepEqual(prompt.request, providerRequest);
  assert.ok(prompt.instructions.some((instruction) => instruction.includes('intentPlan')));
  assert.ok(prompt.instructions.some((instruction) => instruction.includes('somente grounded')));
  assert.equal(result.response.answer, 'Resumo confirmado.');
  assert.equal(result.confirmedCostCents, 20);
  assert.equal(result.durationMs, 25);
});

test('tier complexo mantém o mesmo modelo e usa esforço médio sem ampliar saída', async () => {
  const calls = [];
  await fakeGateway({ calls }).generate({ execution: proExecution, maximumCostCents: 100, providerRequest });
  assert.equal(calls[1].request.model, 'gemini-3.8-flash');
  assert.equal(calls[1].request.config.maxOutputTokens, 1_500);
  assert.deepEqual(calls[1].request.config.thinkingConfig, {
    thinkingLevel: 'MEDIUM', includeThoughts: false,
  });
});

test('preserva continuação efêmera no prompt sem promovê-la a autoridade', async () => {
  const calls = [];
  const continuation = {
    intent: 'financial_overview', clarificationCode: 'period_required',
    previousMessage: 'Prepare um relatório.',
  };
  await fakeGateway({ calls }).generate({
    execution, maximumCostCents: 20,
    providerRequest: { ...providerRequest, message: 'Deste mês.', continuation },
  });
  const prompt = JSON.parse(calls[1].request.contents[0].parts[0].text);
  assert.deepEqual(prompt.request.continuation, continuation);
});

test('planejador define períodos usuais e prefere esclarecer a indisponibilidade', async () => {
  const calls = [];
  const gateway = createVertexRuntimeGateway({
    providerFeatureEnabled: true,
    killSwitchActive: false,
    projectIdReader: () => 'synthetic-project',
    vertexAiFactory: async () => ({
      models: {
        generateContent: async (request) => {
          calls.push(request);
          return {
            candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({
              schemaVersion: 1,
              status: 'ready',
              intent: 'expenses',
              clarificationCode: 'none',
              clarificationQuestion: '',
              periodCode: 'current_month',
              financialTool: 'expenses',
            }) }] } }],
          };
        },
      },
    }),
  });
  const result = await gateway.plan({
    execution: planningExecution,
    maximumCostCents: 20,
    request: { message: 'Como estão meus gastos?' },
  });
  assert.equal(result.plan.periodCode, 'current_month');
  const prompt = JSON.parse(calls[0].contents[0].parts[0].text);
  assert.ok(prompt.instructions.some((item) => item.includes('Sem período explícito')));
  assert.ok(prompt.instructions.some((item) => item.includes('prefira clarification_required')));
});

test('sintetiza somente áudio unary completo com a voz feminina aprovada', async () => {
  const calls = [];
  const pcm = Buffer.alloc(960, 7);
  const gateway = fakeGateway({
    calls,
    result: {
      candidates: [{
        finishReason: 'STOP',
        content: {
          parts: [{
            inlineData: {
              mimeType: 'audio/L16;rate=24000',
              data: pcm.toString('base64'),
            },
          }],
        },
      }],
    },
  });

  const result = await gateway.synthesize({
    maximumCostCents: 20,
    text: 'Resposta validada.',
  });

  const request = calls[1].request;
  assert.equal(request.model, ASSISTANT_VERTEX_SPEECH_MODEL);
  assert.deepEqual(request.config.responseModalities, ['AUDIO']);
  assert.equal(
    request.config.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName,
    ASSISTANT_VERTEX_SPEECH_VOICE,
  );
  assert.equal(request.config.speechConfig.languageCode, 'pt-BR');
  assert.equal(result.audio.mimeType, 'audio/wav');
  const wave = Buffer.from(result.audio.dataBase64, 'base64');
  assert.equal(wave.subarray(0, 4).toString(), 'RIFF');
  assert.equal(wave.subarray(8, 12).toString(), 'WAVE');
  assert.deepEqual(wave.subarray(44), pcm);
});

test('não aceita áudio truncado, parcial ou misturado entre candidatos', async () => {
  const pcm = Buffer.alloc(960, 7).toString('base64');
  for (const result of [
    { candidates: [{ finishReason: 'MAX_TOKENS', content: { parts: [{ inlineData: { mimeType: 'audio/L16', data: pcm } }] } }] },
    { candidates: [{ finishReason: 'STOP', content: { parts: [{ inlineData: { mimeType: 'audio/L16', data: pcm } }, { inlineData: { mimeType: 'audio/L16', data: pcm } }] } }] },
  ]) {
    await assert.rejects(
      fakeGateway({ result }).synthesize({ maximumCostCents: 20, text: 'Resposta validada.' }),
      (error) => error.code === 'assistant_provider_output_invalid',
    );
  }
});

test('extração usa somente o primeiro candidato unary e suas partes textuais', async () => {
  const serialized = providerJson({
    status: 'safe_unavailable', clarificationCode: 'none', assertions: [],
    missingData: ['confirmed_financial_evidence'],
  });
  const split = Math.floor(serialized.length / 2);
  const result = await fakeGateway({ result: {
    candidates: [
      { finishReason: 'STOP', content: { parts: [{ text: serialized.slice(0, split) }, { text: serialized.slice(split) }] } },
      { finishReason: 'STOP', content: { parts: [{ text: providerJson() }] } },
    ],
  } }).generate({ execution, maximumCostCents: 20, providerRequest });
  assert.equal(result.response.status, 'safe_unavailable');
  assert.equal(result.providerDiagnostics.candidateCount, 2);
  assert.equal(result.providerDiagnostics.textPartCount, 2);
});

test('distingue ausência, truncamento, bloqueio e JSON inválido sem reparar saída', async () => {
  const cases = [
    [{ candidates: [] }, 'provider_output_missing', 'ABSENT'],
    [{ candidates: [{ finishReason: 'MAX_TOKENS', content: { parts: [{ text: '{' }] } }] }, 'provider_output_max_tokens', 'MAX_TOKENS'],
    [{ candidates: [{ finishReason: 'SAFETY', content: { parts: [] } }] }, 'provider_output_blocked', 'SAFETY'],
    [{ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: 'não-json' }] } }] }, 'provider_output_invalid_json', 'STOP'],
  ];
  for (const [sdkResult, expectedIssue, expectedFinishReason] of cases) {
    const result = await fakeGateway({ result: sdkResult }).generate({ execution, maximumCostCents: 20, providerRequest });
    assert.equal(result.response, null);
    assert.equal(result.providerOutputIssue, expectedIssue);
    assert.equal(result.providerDiagnostics.finishReason, expectedFinishReason);
  }
});

test('configura endpoint explícito apenas para location global', () => {
  assert.deepEqual(
    assistantVertexClientConfiguration({ projectId: 'synthetic-project', location: 'global' }),
    {
      projectId: 'synthetic-project', location: 'global', apiVersion: 'v1',
      apiEndpoint: 'aiplatform.googleapis.com',
    },
  );
  assert.deepEqual(
    assistantVertexClientConfiguration({ projectId: 'synthetic-project', location: 'southamerica-east1' }),
    { projectId: 'synthetic-project', location: 'southamerica-east1', apiVersion: 'v1' },
  );
});

test('recusa identidade ou segredo antes de alcançar o SDK', async () => {
  const gateway = fakeGateway();
  await assert.rejects(
    gateway.generate({ execution, maximumCostCents: 20, providerRequest: { ...providerRequest, context: { uid: 'proibido' } } }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_provider_request_unsafe',
  );
});
