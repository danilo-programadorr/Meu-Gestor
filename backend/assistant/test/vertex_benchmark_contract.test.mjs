import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSIST_2A_BENCHMARK_CONTRACT,
  assertAggregateBenchmarkMetric,
  assertAggregateBenchmarkRun,
} from '../src/vertex_benchmark_contract.mjs';

const metric = (overrides = {}) => ({
  model: 'gemini-2.5-flash',
  fixture: 'ausencia',
  latencyMs: 120,
  inputTokens: 40,
  outputTokens: 80,
  estimatedCostBrl: 0.01,
  assessment: 'complete',
  qualityScore: 8,
  ...overrides,
});

test('contrato fixa endpoint, modelos GA, limites e recursos proibidos', () => {
  assert.equal(ASSIST_2A_BENCHMARK_CONTRACT.endpoint, 'global');
  assert.deepEqual(ASSIST_2A_BENCHMARK_CONTRACT.models, {
    flash: 'gemini-2.5-flash',
    pro: 'gemini-2.5-pro',
  });
  assert.equal(ASSIST_2A_BENCHMARK_CONTRACT.maxCalls, 8);
  assert.equal(ASSIST_2A_BENCHMARK_CONTRACT.maxInputTokensPerCall, 1500);
  assert.deepEqual(ASSIST_2A_BENCHMARK_CONTRACT.maxOutputTokensByModel, {
    'gemini-2.5-flash': 500,
    'gemini-2.5-pro': 800,
  });
  assert.equal(ASSIST_2A_BENCHMARK_CONTRACT.additionalCeilingBrl, 1.912);
  assert.deepEqual(ASSIST_2A_BENCHMARK_CONTRACT.fixtures, [
    'ausencia', 'contagem', 'seguranca', 'clareza',
  ]);
  assert.deepEqual(ASSIST_2A_BENCHMARK_CONTRACT.assessments, [
    'complete', 'inconclusive_truncated',
  ]);
  assert.deepEqual(ASSIST_2A_BENCHMARK_CONTRACT.forbiddenFeatures, [
    'audio', 'image', 'grounding', 'webSearch', 'cache', 'tools', 'streaming',
  ]);
});

test('aceita somente métricas agregadas, sem prompt ou resposta', () => {
  const result = assertAggregateBenchmarkMetric(metric());
  assert.deepEqual(result, metric());
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ prompt: 'não reter' })), /fields_invalid/);
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ responseText: 'não reter' })), /fields_invalid/);
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ fixture: 'texto livre' })), /identity_invalid/);
  assert.deepEqual(
    assertAggregateBenchmarkMetric(metric({ assessment: 'inconclusive_truncated', qualityScore: null })),
    metric({ assessment: 'inconclusive_truncated', qualityScore: null }),
  );
  assert.throws(
    () => assertAggregateBenchmarkMetric(metric({ assessment: 'inconclusive_truncated', qualityScore: 0 })),
    /assessment_invalid/,
  );
});

test('recusa métricas fora dos limites por chamada', () => {
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ inputTokens: 1501 })), /values_invalid/);
  assert.equal(assertAggregateBenchmarkMetric(metric({ model: 'gemini-2.5-pro', outputTokens: 800 })).outputTokens, 800);
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ outputTokens: 501 })), /values_invalid/);
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ model: 'gemini-2.5-pro', outputTokens: 801 })), /values_invalid/);
  assert.throws(() => assertAggregateBenchmarkMetric(metric({ qualityScore: 11 })), /values_invalid/);
});

test('encerra antes de liberar execução fora da quantidade ou teto adicional', () => {
  assert.throws(() => assertAggregateBenchmarkRun([]), /run_invalid/);
  assert.throws(() => assertAggregateBenchmarkRun(Array.from({ length: 9 }, () => metric())), /run_invalid/);
  assert.throws(
    () => assertAggregateBenchmarkRun([metric({ estimatedCostBrl: 1 }), metric({ estimatedCostBrl: 1 })]),
    /cost_ceiling_exceeded/,
  );
  assert.equal(assertAggregateBenchmarkRun([metric(), metric({ model: 'gemini-2.5-pro' })]).length, 2);
});
