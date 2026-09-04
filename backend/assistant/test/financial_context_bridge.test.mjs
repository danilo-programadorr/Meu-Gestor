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
  timeZone: 'America/Sao_Paulo',
  startDate: '2026-09-01',
  endDateExclusive: '2026-09-03',
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
    async readOwnSource({ ownerUid, reader, period: receivedPeriod, technicalWindow }) {
      assert.equal(ownerUid, 'synthetic-owner');
      assert.equal(receivedPeriod.timeZone, 'America/Sao_Paulo');
      assert.equal(technicalWindow.start.endsWith('Z'), true);
      assert.equal(technicalWindow.endExclusive.endsWith('Z'), true);
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
  assert.deepEqual(context.civilPeriod, period);
  assert.equal(context.facts[0].evidence.alias, 'ev_accounts_001');
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
    createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period: { timeZone: 'America/Sao_Paulo', startDate: period.endDateExclusive, endDateExclusive: period.startDate } }),
    /assistant_invalid_context/,
  );
  await assert.rejects(
    createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period: { timeZone: 'America/Sao_Paulo', startDate: period.startDate, endDateExclusive: '2027-09-02' } }),
    /assistant_invalid_context/,
  );
});

test('converte limites civis com horário de verão histórico sem deslocar o mês', async () => {
  const daylightSavingsPeriod = {
    timeZone: 'America/Sao_Paulo', startDate: '2018-11-03', endDateExclusive: '2018-11-05',
  };
  const context = await createBridge().buildOwnConfirmedContext({
    actor: { uid: 'synthetic-owner' }, period: daylightSavingsPeriod,
  });
  assert.deepEqual(context.technicalWindow, {
    start: '2018-11-03T03:00:00.000Z', endExclusive: '2018-11-05T02:00:00.000Z',
  });
});

test('recusa fato sem fonte, período civil ou evidência correspondente', async () => {
  const context = await createBridge().buildOwnConfirmedContext({ actor: { uid: 'synthetic-owner' }, period });
  for (const alteredFact of [
    { ...context.facts[0], evidence: { ...context.facts[0].evidence, alias: 'ev_other_001' } },
    { ...context.facts[0], civilPeriod: { ...period, timeZone: 'UTC' } },
    { ...context.facts[0], value: 1.5 },
  ]) {
    assert.throws(
      () => assertConfirmedContext({ ...context, facts: [alteredFact, ...context.facts.slice(1)] }),
      /assistant_invalid_context/,
    );
  }
});

test('ponte local não contém acesso a Firebase, banco padrão ou provedor', async () => {
  const source = await readFile(new URL('../src/financial_context_bridge.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /firebase|firestore|vertex|secret manager|https?:\/\//i);
});
