/**
 * Responsabilidade: encapsula o único caminho local previsto para o SDK
 * Vertex, mantendo-o inacessível enquanto os controles fail-closed vigentes
 * não forem explicitamente abertos pelo servidor.
 */
import { deny } from './errors.mjs';

export const ASSISTANT_VERTEX_LOCATION = 'global';

const exactKeys = (value, keys) => value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const unsafeSerializedContext = (value) => /(?:\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|bearer\s+|api[_ -]?key|private[_ -]?key|password|senha|token\s*[:=]|"(?:uid|email|ownerId|projectId)"\s*:)/iu.test(value);

const assertExecution = (execution) => {
  if (!exactKeys(execution, ['enabled', 'fallback', 'providerModel', 'tier'])
      || execution.enabled !== true
      || !['flash', 'pro'].includes(execution.tier)
      || !['gemini-2.5-flash', 'gemini-2.5-pro'].includes(execution.providerModel)
      || execution.fallback !== 'safe_unavailable') {
    throw deny('assistant_provider_plan_invalid');
  }
};

const assertMaximumCost = (maximumCostCents) => {
  if (!Number.isSafeInteger(maximumCostCents) || maximumCostCents < 1) {
    throw deny('assistant_provider_cost_invalid');
  }
};

const assertProjectId = (projectId) => {
  if (typeof projectId !== 'string' || !/^[a-z][a-z0-9-]{5,62}$/u.test(projectId)) {
    throw deny('assistant_provider_configuration_unavailable');
  }
  return projectId;
};

const defaultVertexAiFactory = async ({ projectId }) => {
  const { VertexAI } = await import('@google-cloud/vertexai');
  return new VertexAI({ project: projectId, location: ASSISTANT_VERTEX_LOCATION });
};

const defaultProjectIdReader = () => process.env.GCLOUD_PROJECT;

const extractJsonResponse = (result) => {
  const parts = result?.response?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts.map((part) => part?.text).filter((part) => typeof part === 'string').join('')
    : null;
  if (typeof text !== 'string' || text.length < 2 || text.length > 20_000) {
    throw deny('assistant_provider_response_invalid');
  }
  try {
    return JSON.parse(text);
  } catch {
    throw deny('assistant_provider_response_invalid');
  }
};

const createPrompt = (providerRequest) => {
  const serialized = JSON.stringify(providerRequest);
  if (unsafeSerializedContext(serialized)) {
    throw deny('assistant_provider_request_unsafe');
  }
  return serialized;
};

/**
 * Cria a fronteira de runtime injetável. A identidade da Function é a única
 * fonte futura de ADC; testes substituem o cliente e jamais alcançam rede.
 */
export const createVertexRuntimeGateway = ({
  providerFeatureEnabled = false,
  killSwitchActive = true,
  projectIdReader = defaultProjectIdReader,
  vertexAiFactory = defaultVertexAiFactory,
  clock = () => Date.now(),
} = {}) => {
  if (typeof providerFeatureEnabled !== 'boolean' || typeof killSwitchActive !== 'boolean'
      || typeof projectIdReader !== 'function' || typeof vertexAiFactory !== 'function'
      || typeof clock !== 'function') {
    throw new TypeError('assistant_vertex_gateway_dependencies_invalid');
  }

  return Object.freeze({
    async generate({ execution, maximumCostCents, providerRequest }) {
      if (killSwitchActive || !providerFeatureEnabled) {
        throw deny('assistant_provider_unavailable');
      }
      assertExecution(execution);
      assertMaximumCost(maximumCostCents);
      const prompt = createPrompt(providerRequest);
      const projectId = assertProjectId(await projectIdReader());
      const startedAt = clock();
      const vertexAi = await vertexAiFactory({ projectId, location: ASSISTANT_VERTEX_LOCATION });
      if (!vertexAi || typeof vertexAi.getGenerativeModel !== 'function') {
        throw deny('assistant_provider_configuration_unavailable');
      }
      const model = vertexAi.getGenerativeModel({
        model: execution.providerModel,
        generationConfig: Object.freeze({
          temperature: 0,
          maxOutputTokens: execution.tier === 'flash' ? 800 : 1_500,
          responseMimeType: 'application/json',
        }),
      });
      if (!model || typeof model.generateContent !== 'function') {
        throw deny('assistant_provider_configuration_unavailable');
      }
      const result = await model.generateContent({
        contents: [Object.freeze({ role: 'user', parts: [Object.freeze({ text: prompt })] })],
      });
      const durationMs = clock() - startedAt;
      if (!Number.isSafeInteger(durationMs) || durationMs < 0) {
        throw deny('assistant_provider_duration_invalid');
      }
      return Object.freeze({
        response: extractJsonResponse(result),
        durationMs,
        // Until a future authoritative billing reconciliation exists, the full
        // reservation stays accounted; no unmeasured capacity is released.
        confirmedCostCents: maximumCostCents,
      });
    },
  });
};
