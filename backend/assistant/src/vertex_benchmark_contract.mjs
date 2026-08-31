const METRIC_FIELDS = Object.freeze([
  'model',
  'fixture',
  'latencyMs',
  'inputTokens',
  'outputTokens',
  'estimatedCostBrl',
  'assessment',
  'qualityScore',
]);

export const ASSIST_2A_BENCHMARK_CONTRACT = Object.freeze({
  endpoint: 'global',
  models: Object.freeze({
    flash: 'gemini-2.5-flash',
    pro: 'gemini-2.5-pro',
  }),
  fixtures: Object.freeze(['ausencia', 'contagem', 'seguranca', 'clareza']),
  maxCalls: 8,
  maxInputTokensPerCall: 1500,
  maxOutputTokensByModel: Object.freeze({
    'gemini-2.5-flash': 500,
    'gemini-2.5-pro': 800,
  }),
  additionalCeilingBrl: 1.912,
  forbiddenFeatures: Object.freeze([
    'audio',
    'image',
    'grounding',
    'webSearch',
    'cache',
    'tools',
    'streaming',
  ]),
  assessments: Object.freeze(['complete', 'inconclusive_truncated']),
  metricFields: METRIC_FIELDS,
});

const isFiniteNumberInRange = (value, minimum, maximum) =>
  typeof value === 'number' && Number.isFinite(value) && value >= minimum && value <= maximum;

/**
 * Accepts only aggregate, bounded benchmark metrics. Prompts and provider
 * responses intentionally have no representation in this contract.
 */
export const assertAggregateBenchmarkMetric = (metric) => {
  if (!metric || typeof metric !== 'object' || Array.isArray(metric)) {
    throw new TypeError('assistant_benchmark_metric_invalid');
  }

  const keys = Object.keys(metric).sort();
  const expectedKeys = [...METRIC_FIELDS].sort();
  if (keys.length !== expectedKeys.length || keys.some((key, index) => key !== expectedKeys[index])) {
    throw new TypeError('assistant_benchmark_metric_fields_invalid');
  }

  const knownModels = Object.values(ASSIST_2A_BENCHMARK_CONTRACT.models);
  if (!knownModels.includes(metric.model)
      || !ASSIST_2A_BENCHMARK_CONTRACT.fixtures.includes(metric.fixture)) {
    throw new TypeError('assistant_benchmark_metric_identity_invalid');
  }

  if (!ASSIST_2A_BENCHMARK_CONTRACT.assessments.includes(metric.assessment)
      || !isFiniteNumberInRange(metric.latencyMs, 0, Number.MAX_SAFE_INTEGER)
      || !isFiniteNumberInRange(metric.inputTokens, 0, ASSIST_2A_BENCHMARK_CONTRACT.maxInputTokensPerCall)
      || !isFiniteNumberInRange(metric.outputTokens, 0, ASSIST_2A_BENCHMARK_CONTRACT.maxOutputTokensByModel[metric.model])
      || !isFiniteNumberInRange(metric.estimatedCostBrl, 0, ASSIST_2A_BENCHMARK_CONTRACT.additionalCeilingBrl)) {
    throw new TypeError('assistant_benchmark_metric_values_invalid');
  }
  if (metric.assessment === 'complete'
      && !isFiniteNumberInRange(metric.qualityScore, 0, 10)) {
    throw new TypeError('assistant_benchmark_metric_values_invalid');
  }
  if (metric.assessment === 'inconclusive_truncated' && metric.qualityScore !== null) {
    throw new TypeError('assistant_benchmark_metric_assessment_invalid');
  }

  return Object.freeze({ ...metric });
};

export const assertAggregateBenchmarkRun = (metrics) => {
  if (!Array.isArray(metrics) || metrics.length == 0 || metrics.length > ASSIST_2A_BENCHMARK_CONTRACT.maxCalls) {
    throw new TypeError('assistant_benchmark_run_invalid');
  }

  const sanitized = metrics.map(assertAggregateBenchmarkMetric);
  const totalCostBrl = sanitized.reduce((total, metric) => total + metric.estimatedCostBrl, 0);
  if (totalCostBrl > ASSIST_2A_BENCHMARK_CONTRACT.additionalCeilingBrl) {
    throw new TypeError('assistant_benchmark_cost_ceiling_exceeded');
  }
  return Object.freeze(sanitized);
};
