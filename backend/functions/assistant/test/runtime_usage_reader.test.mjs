import assert from 'node:assert/strict';
import test from 'node:test';

import { createAssistantOwnerScope } from '../shared/index.mjs';
import { createAssistantRuntimeUsageReader } from '../src/runtime_usage_reader.mjs';

test('leitor de uso deriva escopo opaco somente do UID autenticado em memória', async () => {
  let received;
  const reader = createAssistantRuntimeUsageReader({
    ledger: {
      readUsage: async ({ ownerScope }) => {
        received = ownerScope;
        return { costUnitsInWindow: 3, proCallsInWindow: 1 };
      },
    },
  });
  assert.deepEqual(await reader({ uid: 'synthetic-authenticated-owner' }), {
    costUnitsInWindow: 3, proCallsInWindow: 1,
  });
  assert.equal(received, createAssistantOwnerScope('synthetic-authenticated-owner'));
  assert.doesNotMatch(received, /synthetic|uid|email/iu);
});

test('leitor de uso falha fechado sem ledger ou identidade autenticada válida', async () => {
  assert.throws(() => createAssistantRuntimeUsageReader(), /assistant_runtime_usage_ledger_invalid/);
  const reader = createAssistantRuntimeUsageReader({ ledger: { readUsage: async () => ({}) } });
  await assert.rejects(reader({}), /assistant_owner_scope_invalid/);
});
