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

test('diagnóstico sanitizado rejeita campos ou valores fora do contrato', () => {
  const diagnostics = createSanitizedAssistantRuntimeDiagnostics({ emit: () => undefined });
  assert.throws(
    () => diagnostics.report({ stage: 'owner_scoped_context_and_usage', outcome: 'failed', uid: 'synthetic-user' }),
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
    () => diagnostics.report({
      stage: 'usage_adc_credentials', outcome: 'failed', reason: 'timeout', url: 'forbidden',
    }),
    /assistant_runtime_diagnostics_event_invalid/,
  );
});
