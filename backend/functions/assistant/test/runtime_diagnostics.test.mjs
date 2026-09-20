import assert from 'node:assert/strict';
import test from 'node:test';

import { createSanitizedAssistantRuntimeDiagnostics } from '../src/runtime_diagnostics.mjs';

test('diagnóstico sanitizado emite somente evento, estágio e resultado enumerados', () => {
  const emitted = [];
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: (line) => emitted.push(line) });
  diagnostics.report({ stage: 'owner_scoped_context_and_usage', outcome: 'failed' });
  assert.deepEqual(emitted, [
    '{"event":"assistant_runtime_stage","stage":"owner_scoped_context_and_usage","outcome":"failed"}',
  ]);
  assert.deepEqual(JSON.parse(emitted[0]), {
    event: 'assistant_runtime_stage', stage: 'owner_scoped_context_and_usage', outcome: 'failed',
  });
  assert.doesNotMatch(emitted[0], /synthetic|bearer|@|\d{4}-\d{2}-\d{2}/iu);
});

test('diagnóstico individual aceita somente motivo fechado em falha de leitor', () => {
  const emitted = [];
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: (line) => emitted.push(line) });
  diagnostics.report({
    stage: 'owner_scoped_context',
    outcome: 'failed',
    reason: 'period_invalid',
  });
  diagnostics.report({ stage: 'usage_reader', outcome: 'passed' });

  assert.deepEqual(emitted.map(JSON.parse), [
    {
      event: 'assistant_runtime_stage',
      stage: 'owner_scoped_context',
      outcome: 'failed',
      reason: 'period_invalid',
    },
    { event: 'assistant_runtime_stage', stage: 'usage_reader', outcome: 'passed' },
  ]);
  assert.doesNotMatch(emitted.join(''), /synthetic|bearer|@|stack|message/iu);
});

test('diagnóstico do uso separa ADC e HTTP sem aceitar metadados sensíveis', () => {
  const emitted = [];
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: (line) => emitted.push(line) });
  diagnostics.report({ stage: 'usage_adc_credentials', outcome: 'passed' });
  diagnostics.report({
    stage: 'usage_adc_credentials',
    outcome: 'failed',
    reason: 'adc_authentication_unavailable',
    httpStatus: 503,
  });
  diagnostics.report({
    stage: 'usage_firestore_begin_transaction', outcome: 'passed', httpStatus: 200,
  });
  diagnostics.report({
    stage: 'usage_firestore_read', outcome: 'failed', reason: 'document_missing', httpStatus: 404,
  });

  assert.deepEqual(emitted.map(JSON.parse), [
    { event: 'assistant_runtime_stage', stage: 'usage_adc_credentials', outcome: 'passed' },
    {
      event: 'assistant_runtime_stage',
      stage: 'usage_adc_credentials',
      outcome: 'failed',
      reason: 'adc_authentication_unavailable',
      httpStatus: 503,
    },
    {
      event: 'assistant_runtime_stage',
      stage: 'usage_firestore_begin_transaction',
      outcome: 'passed',
      httpStatus: 200,
    },
    {
      event: 'assistant_runtime_stage',
      stage: 'usage_firestore_read',
      outcome: 'failed',
      reason: 'document_missing',
      httpStatus: 404,
    },
  ]);
  assert.ok(emitted.map(JSON.parse).every((event) => Object.keys(event).every(
    (key) => ['event', 'stage', 'outcome', 'reason', 'httpStatus'].includes(key),
  )));
  assert.doesNotMatch(emitted.join(''), /synthetic|bearer|@/iu);
});

test('diagnóstico do plano preserva somente código interno enumerado', () => {
  const emitted = [];
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: (line) => emitted.push(line) });
  diagnostics.report({
    stage: 'activation_plan', outcome: 'failed', code: 'assistant_context_limit_exceeded',
  });
  assert.deepEqual(emitted.map(JSON.parse), [{
    event: 'assistant_runtime_stage',
    stage: 'activation_plan',
    outcome: 'failed',
    code: 'assistant_context_limit_exceeded',
  }]);
  assert.doesNotMatch(emitted[0], /message|stack|bearer|@/iu);
});

test('diagnóstico final distingue grounded e fallback por motivo fechado', () => {
  const emitted = [];
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: (line) => emitted.push(line) });
  diagnostics.report({
    stage: 'response_validation', outcome: 'passed', finalStatus: 'grounded',
  });
  diagnostics.report({
    stage: 'response_validation',
    outcome: 'passed',
    finalStatus: 'safe_unavailable',
    reason: 'provider_reported_insufficient_evidence',
  });
  diagnostics.report({
    stage: 'response_validation',
    outcome: 'passed',
    finalStatus: 'safe_unavailable',
    reason: 'assertion_evidence_non_numeric',
  });
  diagnostics.report({
    stage: 'response_validation',
    outcome: 'passed',
    finalStatus: 'safe_unavailable',
    reason: 'assertion_numeric_value_mismatch',
  });
  assert.deepEqual(emitted.map(JSON.parse), [
    {
      event: 'assistant_runtime_stage',
      stage: 'response_validation',
      outcome: 'passed',
      finalStatus: 'grounded',
    },
    {
      event: 'assistant_runtime_stage',
      stage: 'response_validation',
      outcome: 'passed',
      finalStatus: 'safe_unavailable',
      reason: 'provider_reported_insufficient_evidence',
    },
    {
      event: 'assistant_runtime_stage',
      stage: 'response_validation',
      outcome: 'passed',
      finalStatus: 'safe_unavailable',
      reason: 'assertion_evidence_non_numeric',
    },
    {
      event: 'assistant_runtime_stage',
      stage: 'response_validation',
      outcome: 'passed',
      finalStatus: 'safe_unavailable',
      reason: 'assertion_numeric_value_mismatch',
    },
  ]);
  assert.doesNotMatch(emitted.join(''), /message|stack|bearer|@|responseText|statement|evidenceValue/iu);
});

test('diagnóstico sanitizado rejeita campos ou valores fora do contrato', () => {
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: () => undefined });
  assert.throws(
    () => diagnostics.report({ stage: 'owner_scoped_context_and_usage', outcome: 'failed', uid: 'synthetic-user' }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({
      stage: 'response_validation',
      outcome: 'passed',
      finalStatus: 'safe_unavailable',
      reason: 'guessed_reason',
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({ stage: 'unknown', outcome: 'failed' }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({
      stage: 'usage_reader', outcome: 'failed', reason: 'guessed_reason',
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({
      stage: 'runtime_controls', outcome: 'failed', reason: 'unclassified',
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({
      stage: 'usage_firestore_commit', outcome: 'failed', reason: 'timeout', httpStatus: 99,
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({ stage: 'usage_firestore_read', outcome: 'failed' }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({ stage: 'activation_plan', outcome: 'failed', code: 'unknown' }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({ stage: 'activation_plan', outcome: 'failed' }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
  assert.throws(
    () => diagnostics.report({
      stage: 'usage_adc_credentials', outcome: 'failed', reason: 'timeout', url: 'forbidden',
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
});
