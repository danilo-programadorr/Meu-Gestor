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
});
