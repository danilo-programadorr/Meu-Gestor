import assert from 'node:assert/strict';
import test from 'node:test';

import { createAssistantOwnerScope } from '../../../assistant/src/cost_control_ledger.mjs';
import {
  assistantOwnerScope,
  createAssistantUsagePrivacyTarget,
} from '../src/assistant_usage_privacy_target.mjs';

test('remove somente uso e requisições do proprietário no ledger nomeado', async () => {
  const ownerId = 'synthetic-owner-a';
  const otherId = 'synthetic-owner-b';
  const ownScope = assistantOwnerScope(ownerId);
  const otherScope = assistantOwnerScope(otherId);
  assert.equal(ownScope, createAssistantOwnerScope(ownerId));
  const fixture = fakeFirestore({
    daily: { '2026-10-18': { reservedCostCents: 10, confirmedCostCents: 5 } },
    monthly: { '2026-10': { reservedCostCents: 10, confirmedCostCents: 5 } },
    usage: {
      [ownScope]: { windowDay: '2026-10-18', costUnitsInWindow: 2, proCallsInWindow: 0 },
      [otherScope]: { windowDay: '2026-10-18', costUnitsInWindow: 1, proCallsInWindow: 0 },
    },
    records: {
      own: { ownerScope: ownScope },
      other: { ownerScope: otherScope },
    },
    periods: { own: { dayKey: '2026-10-18' }, other: { dayKey: '2026-10-18' } },
  });
  await createAssistantUsagePrivacyTarget({ firestore: fixture.firestore })
    .deleteOwner({ ownerId });
  assert.equal(Object.hasOwn(fixture.state.usage, ownScope), false);
  assert.equal(Object.hasOwn(fixture.state.records, 'own'), false);
  assert.equal(Object.hasOwn(fixture.state.periods, 'own'), false);
  assert.equal(Object.hasOwn(fixture.state.usage, otherScope), true);
  assert.equal(Object.hasOwn(fixture.state.records, 'other'), true);
  assert.deepEqual(fixture.state.daily, {
    '2026-10-18': { reservedCostCents: 10, confirmedCostCents: 5 },
  });
});

test('falha fechada sem reescrever ledger inconsistente', async () => {
  const fixture = fakeFirestore({ daily: {}, monthly: {}, usage: {}, records: {}, periods: { orphan: {} } });
  await assert.rejects(
    () => createAssistantUsagePrivacyTarget({ firestore: fixture.firestore })
      .deleteOwner({ ownerId: 'synthetic-owner-a' }),
    (error) => error?.code === 'privacy_assistant_ledger_inconsistent',
  );
  assert.equal(fixture.writes, 0);
});

function fakeFirestore(initial) {
  const fixture = { state: structuredClone(initial), writes: 0 };
  const reference = {};
  fixture.firestore = {
    doc: (path) => {
      assert.equal(path, 'assistantRuntime/ledger');
      return reference;
    },
    runTransaction: async (callback) => callback({
      get: async (received) => {
        assert.equal(received, reference);
        return { exists: true, data: () => structuredClone(fixture.state) };
      },
      set: (received, value) => {
        assert.equal(received, reference);
        fixture.state = structuredClone(value);
        fixture.writes += 1;
      },
    }),
  };
  return fixture;
}
