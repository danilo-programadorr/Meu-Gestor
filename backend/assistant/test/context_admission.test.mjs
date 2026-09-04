import assert from 'node:assert/strict';
import test from 'node:test';

import {
  admitOwnFinancialContext,
  AssistantContractError,
  DEFAULT_ASSISTANT_CONTEXT_SCOPE,
} from '../src/index.mjs';

const authorization = (overrides = {}) => ({
  authenticated: true,
  financialPrivacyActive: false,
  ...overrides,
});

const period = Object.freeze({
  timeZone: 'America/Sao_Paulo', startDate: '2026-09-01', endDateExclusive: '2026-10-01',
});

test('admite somente escopo próprio, finito e período civil inequívoco', () => {
  const plan = admitOwnFinancialContext({ authorization: authorization(), scope: DEFAULT_ASSISTANT_CONTEXT_SCOPE, civilPeriod: period });
  assert.equal(plan.ownerOnly, true);
  assert.equal(plan.timeZone, 'America/Sao_Paulo');
  assert.deepEqual(plan.civilPeriod, period);
  assert.equal(plan.technicalWindow.start, '2026-09-01T03:00:00.000Z');
  assert.equal(plan.technicalWindow.endExclusive, '2026-10-01T03:00:00.000Z');
});

for (const [name, input] of [
  ['privacidade financeira', { authorization: authorization({ financialPrivacyActive: true }), scope: DEFAULT_ASSISTANT_CONTEXT_SCOPE, civilPeriod: period, code: 'assistant_financial_privacy_active' }],
  ['fonte de terceiro', { authorization: authorization(), scope: { kind: 'own_financial_information', sources: ['privateDirectory'] }, civilPeriod: period, code: 'assistant_context_admission_denied' }],
  ['escopo excessivo', { authorization: authorization(), scope: { kind: 'own_financial_information', sources: Array(10).fill('accounts') }, civilPeriod: period, code: 'assistant_context_admission_denied' }],
  ['período ambíguo', { authorization: authorization(), scope: DEFAULT_ASSISTANT_CONTEXT_SCOPE, civilPeriod: { timeZone: 'UTC', startDate: '2026-09-01', endDateExclusive: '2026-10-01' }, code: 'assistant_context_admission_denied' }],
]) {
  test(`falha fechada com ${name}`, () => {
    assert.throws(
      () => admitOwnFinancialContext(input),
      (error) => error instanceof AssistantContractError && error.code === input.code,
    );
  });
}
