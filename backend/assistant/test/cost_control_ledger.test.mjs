import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_COST_LEDGER_STATE,
  AssistantCostControlLedger,
  InMemoryAssistantCostLedgerStore,
  createAssistantOwnerScope,
} from '../src/index.mjs';
import { AssistantContractError } from '../src/errors.mjs';

const requestId = (number) => `00000000-0000-4000-8000-${String(number).padStart(12, '0')}`;
const serverTime = () => new Date('2026-08-31T14:00:00.000Z');
const ownerScope = createAssistantOwnerScope('synthetic-owner-a');
const otherOwnerScope = createAssistantOwnerScope('synthetic-owner-b');
const initialState = (scopes = [ownerScope]) => ({
  daily: {}, monthly: {}, periods: {}, records: {},
  usage: Object.fromEntries(scopes.map((scope) => [scope, {
    windowDay: '2026-08-31', costUnitsInWindow: 0, proCallsInWindow: 0,
  }])),
});
const createLedger = (store = new InMemoryAssistantCostLedgerStore(initialState()), limits = undefined) => ({
  store,
  ledger: new AssistantCostControlLedger({ store, clock: serverTime, ...(limits ? { limits } : {}) }),
});
const reserve = (ledger, { id, tier, cents }) => ledger.reserve({
  requestId: requestId(id),
  tier,
  maximumCostCents: cents,
  ownerScope,
  usageCostUnits: tier === 'flash' ? 1 : 8,
});

test('reserva é atômica, idempotente e registra somente campos permitidos', async () => {
  const { ledger, store } = createLedger();
  const first = await reserve(ledger, { id: 1, tier: 'flash', cents: 125 });
  const repeated = await reserve(ledger, { id: 1, tier: 'flash', cents: 125 });
  assert.deepEqual(repeated, first);
  assert.deepEqual(first, {
    requestId: requestId(1), tier: 'flash', ownerScope, usageCostUnits: 1, durationMs: null,
    reservedCostCents: 125, confirmedCostCents: null, state: ASSISTANT_COST_LEDGER_STATE.reserved,
  });
  assert.deepEqual(Object.keys(store.snapshot().records[requestId(1)]).sort(), [
    'confirmedCostCents', 'durationMs', 'ownerScope', 'requestId', 'reservedCostCents', 'state', 'tier', 'usageCostUnits',
  ]);
});

test('concorrência respeita o teto diário antes de qualquer chamada futura', async () => {
  const { ledger } = createLedger(undefined, { dailyLimitCents: 500, monthlyOperationalLimitCents: 4_500 });
  const results = await Promise.allSettled([
    reserve(ledger, { id: 2, tier: 'flash', cents: 300 }),
    reserve(ledger, { id: 3, tier: 'pro', cents: 300 }),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  const rejected = results.find((result) => result.status === 'rejected').reason;
  assert.equal(rejected.code, 'assistant_cost_daily_limit_reached');
});

test('confirmação reconcilia somente custo medido e repetição não duplica valor', async () => {
  const { ledger, store } = createLedger();
  await reserve(ledger, { id: 4, tier: 'pro', cents: 200 });
  const confirmed = await ledger.confirm({ requestId: requestId(4), durationMs: 40, confirmedCostCents: 120 });
  const repeated = await ledger.confirm({ requestId: requestId(4), durationMs: 40, confirmedCostCents: 120 });
  assert.deepEqual(repeated, confirmed);
  assert.equal(confirmed.state, ASSISTANT_COST_LEDGER_STATE.confirmed);
  assert.deepEqual(store.snapshot().daily['2026-08-31'], { reservedCostCents: 0, confirmedCostCents: 120 });
});

test('confirmação após a virada do dia reconcilia a reserva no período original', async () => {
  let now = new Date('2026-08-31T23:59:59.000Z');
  const store = new InMemoryAssistantCostLedgerStore(initialState());
  const ledger = new AssistantCostControlLedger({ store, clock: () => now });
  await reserve(ledger, { id: 40, tier: 'flash', cents: 100 });
  now = new Date('2026-09-01T00:00:01.000Z');
  await ledger.confirm({ requestId: requestId(40), durationMs: 20, confirmedCostCents: 80 });
  const snapshot = store.snapshot();
  assert.deepEqual(snapshot.daily['2026-08-31'], { reservedCostCents: 0, confirmedCostCents: 80 });
  assert.deepEqual(snapshot.monthly['2026-08'], { reservedCostCents: 0, confirmedCostCents: 80 });
});

test('reinício preserva reserva, falha fechada sem reserva e rejeita estado inconsistente', async () => {
  const initial = createLedger();
  await reserve(initial.ledger, { id: 5, tier: 'flash', cents: 100 });
  const resumed = createLedger(new InMemoryAssistantCostLedgerStore(initial.store.snapshot()));
  await resumed.ledger.confirm({ requestId: requestId(5), durationMs: 10, confirmedCostCents: 90 });
  await assert.rejects(
    resumed.ledger.confirm({ requestId: requestId(6), durationMs: 10, confirmedCostCents: 90 }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_cost_reservation_required',
  );
  const broken = resumed.store.snapshot();
  broken.daily['2026-08-31'].reservedCostCents = -1;
  assert.throws(() => new InMemoryAssistantCostLedgerStore(broken), /assistant_cost_ledger_inconsistent/);
});

test('teto mensal bloqueia e custo confirmado maior do que a reserva é negado', async () => {
  const { ledger } = createLedger(undefined, { dailyLimitCents: 1_000, monthlyOperationalLimitCents: 150 });
  await reserve(ledger, { id: 7, tier: 'flash', cents: 150 });
  await assert.rejects(
    reserve(ledger, { id: 8, tier: 'flash', cents: 1 }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_cost_monthly_limit_reached',
  );
  await assert.rejects(
    ledger.confirm({ requestId: requestId(7), durationMs: 1, confirmedCostCents: 151 }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_cost_confirmed_cost_exceeds_reservation',
  );
});

test('uso é owner-scoped, exige registro existente e nunca retorna zero como fallback', async () => {
  const { ledger } = createLedger(new InMemoryAssistantCostLedgerStore(initialState([ownerScope])));
  assert.deepEqual(await ledger.readUsage({ ownerScope }), {
    costUnitsInWindow: 0, proCallsInWindow: 0,
  });
  await assert.rejects(
    ledger.readUsage({ ownerScope: otherOwnerScope }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_usage_record_required',
  );
});

test('reserva revalida janela do proprietário atomicamente contra concorrência e é idempotente', async () => {
  const { ledger, store } = createLedger(
    new InMemoryAssistantCostLedgerStore({
      ...initialState(),
      usage: {
        [ownerScope]: { windowDay: '2026-08-31', costUnitsInWindow: 31, proCallsInWindow: 0 },
      },
    }),
    { dailyLimitCents: 1_000, monthlyOperationalLimitCents: 4_500 },
  );
  const results = await Promise.allSettled([
    reserve(ledger, { id: 90, tier: 'flash', cents: 20 }),
    reserve(ledger, { id: 91, tier: 'flash', cents: 20 }),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(
    results.find((result) => result.status === 'rejected').reason.code,
    'assistant_usage_limit_reached',
  );
  const repeated = await reserve(ledger, { id: 90, tier: 'flash', cents: 20 });
  assert.equal(repeated.requestId, requestId(90));
  assert.equal(store.snapshot().usage[ownerScope].costUnitsInWindow, 32);
});
