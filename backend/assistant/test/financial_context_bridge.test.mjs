import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import {
  ASSISTANT_FINANCIAL_CONTEXT_SOURCE_READERS,
  AssistantContractError,
  AssistantFinancialContextBridge,
  assertConfirmedContext,
} from '../src/index.mjs';

const period = Object.freeze({
  start: '2026-09-01T03:00:00.000Z',
  end: '2026-09-03T12:00:00.000Z',
});

const snapshots = Object.freeze({
  accounts: { confirmed: true, facts: [{ source: 'accounts', kind: 'moneyCentsBrl', value: 125000 }] },
  transactions: { confirmed: true, facts: [{ source: 'transactions', kind: 'moneyCentsBrl', value: -4500 }] },
  commitments: { confirmed: true, facts: [{ source: 'payables', kind: 'moneyCentsBrl', value: 9800 }] },
  financialCalendar: { confirmed: true, facts: [{ source: 'financialCalendar', kind: 'utcInstant', value: '2026-09-10T03:00:00.000Z' }] },
  investments: { confirmed: true, facts: [{ source: 'investmentAssets', kind: 'safeLabel', value: 'Ativo listado' }] },
  income: { confirmed: true, facts: [{ source: 'investmentIncome', kind: 'moneyCentsBrl', value: 321 }] },
});

const createBridge = (overrides = {}) => new AssistantFinancialContextBridge({
  clock: { now: () => new Date('2026-09-03T12:00:00.000Z') },
  sourceReaders: {
    async readOwnSource({ ownerUid, reader, period: receivedPeriod }) {
      assert.equal(ownerUid, 'synthetic-owner');
      assert.deepEqual(receivedPeriod, period);
      return overrides[reader] ?? snapshots[reader];
    },
  },
});

test('mapeia fontes próprias permitidas em fatos mínimos com aliases efêmeros', async () => {
  const context = await createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period });
  assert.deepEqual(ASSISTANT_FINANCIAL_CONTEXT_SOURCE_READERS, ['accounts', 'transactions', 'commitments', 'financialCalendar', 'investments', 'income']);
  assert.deepEqual(context.facts.map((fact) => fact.evidenceId), [
    'ev_accounts_001', 'ev_transactions_002', 'ev_payables_003',
    'ev_financialcalendar_004', 'ev_investmentassets_005', 'ev_investmentincome_006',
  ]);
  assert.equal(context.facts[0].value, 125000);
  assert.doesNotMatch(JSON.stringify(context), /synthetic-owner|uid|email|token|secret|key/i);
  assert.doesNotThrow(() => assertConfirmedContext(context));
});

test('falha fechada quando uma fonte própria não está confirmada', async () => {
  await assert.rejects(
    createBridge({
    commitments: { confirmed: false, facts: [] },
    investments: { confirmed: false, facts: [] },
    }).buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_invalid_context',
  );
});

for (const [name, override] of [
  ['ID persistido', { accounts: { confirmed: true, facts: [{ source: 'accounts', kind: 'moneyCentsBrl', value: 100, documentId: 'never-send' }] } }],
  ['valor flutuante', { transactions: { confirmed: true, facts: [{ source: 'transactions', kind: 'moneyCentsBrl', value: 1.5 }] } }],
  ['texto sensível', { investments: { confirmed: true, facts: [{ source: 'investmentAssets', kind: 'safeLabel', value: 'token=never-send' }] } }],
  ['fonte de terceiro', { income: { confirmed: true, facts: [{ source: 'privateDirectory', kind: 'integer', value: 1 }] } }],
]) {
  test(`falha fechada com ${name}`, async () => {
    await assert.rejects(
      createBridge(override).buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period }),
      (error) => error instanceof AssistantContractError && error.code === 'assistant_invalid_context',
    );
  });
}

test('recusa período inválido ou posterior ao relógio confiável', async () => {
  await assert.rejects(
    createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period: { start: period.end, end: period.start } }),
    /assistant_invalid_context/,
  );
  await assert.rejects(
    createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period: { start: period.start, end: '2026-09-04T00:00:00.000Z' } }),
    /assistant_invalid_context/,
  );
});

test('ponte local não contém acesso a Firebase, banco padrão ou provedor', async () => {
  const source = await readFile(new URL('../src/financial_context_bridge.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /firebase|firestore|vertex|secret manager|https?:\/\//i);
});
