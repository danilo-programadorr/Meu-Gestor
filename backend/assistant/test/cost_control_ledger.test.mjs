import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ASSISTANT_COST_LEDGER_STATE,
  AssistantCostControlLedger,
  InMemoryAssistantCostLedgerStore,
} from '../src/index.mjs';
import { AssistantContractError } from '../src/errors.mjs';

const requestId = (number) => `00000000-0000-4000-8000-${String(number).padStart(12, '0')}`;
const serverTime = () => new Date('2026-08-31T14:00:00.000Z');
const createLedger = (store = new InMemoryAssistantCostLedgerStore(), limits = undefined) => ({
  store,
  ledger: new AssistantCostControlLedger({ store, clock: serverTime, ...(limits ? { limits } : {}) }),
});

test('reserva é atômica, idempotente e registra somente campos permitidos', async () => {
  const { ledger, store } = createLedger();
  const first = await ledger.reserve({ requestId: requestId(1), tier: 'flash', maximumCostCents: 125 });
  const repeated = await ledger.reserve({ requestId: requestId(1), tier: 'flash', maximumCostCents: 125 });
  assert.deepEqual(repeated, first);
  assert.deepEqual(first, {
    requestId: requestId(1), tier: 'flash', durationMs: null,
    reservedCostCents: 125, confirmedCostCents: null, state: ASSISTANT_COST_LEDGER_STATE.reserved,
  });
  assert.deepEqual(Object.keys(store.snapshot().records[requestId(1)]).sort(), [
    'confirmedCostCents', 'durationMs', 'requestId', 'reservedCostCents', 'state', 'tier',
  ]);
});

test('concorrência respeita o teto diário antes de qualquer chamada futura', async () => {
  const { ledger } = createLedger(undefined, { dailyLimitCents: 500, monthlyOperationalLimitCents: 4_500 });
  const results = await Promise.allSettled([
    ledger.reserve({ requestId: requestId(2), tier: 'flash', maximumCostCents: 300 }),
    ledger.reserve({ requestId: requestId(3), tier: 'pro', maximumCostCents: 300 }),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  const rejected = results.find((result) => result.status === 'rejected').reason;
  assert.equal(rejected.code, 'assistant_cost_daily_limit_reached');
});

test('confirmação reconcilia somente custo medido e repetição não duplica valor', async () => {
  const { ledger, store } = createLedger();
  await ledger.reserve({ requestId: requestId(4), tier: 'pro', maximumCostCents: 200 });
  const confirmed = await ledger.confirm({ requestId: requestId(4), durationMs: 40, confirmedCostCents: 120 });
  const repeated = await ledger.confirm({ requestId: requestId(4), durationMs: 40, confirmedCostCents: 120 });
  assert.deepEqual(repeated, confirmed);
  assert.equal(confirmed.state, ASSISTANT_COST_LEDGER_STATE.confirmed);
  assert.deepEqual(store.snapshot().daily['2026-08-31'], { reservedCostCents: 0, confirmedCostCents: 120 });
});

test('confirmação após a virada do dia reconcilia a reserva no período original', async () => {
  let now = new Date('2026-08-31T23:59:59.000Z');
  const store = new InMemoryAssistantCostLedgerStore();
  const ledger = new AssistantCostControlLedger({ store, clock: () => now });
  await ledger.reserve({ requestId: requestId(40), tier: 'flash', maximumCostCents: 100 });
  now = new Date('2026-09-01T00:00:01.000Z');
  await ledger.confirm({ requestId: requestId(40), durationMs: 20, confirmedCostCents: 80 });
  const snapshot = store.snapshot();
  assert.deepEqual(snapshot.daily['2026-08-31'], { reservedCostCents: 0, confirmedCostCents: 80 });
  assert.deepEqual(snapshot.monthly['2026-08'], { reservedCostCents: 0, confirmedCostCents: 80 });
});

test('reinício preserva reserva, falha fechada sem reserva e rejeita estado inconsistente', async () => {
  const initial = createLedger();
  await initial.ledger.reserve({ requestId: requestId(5), tier: 'flash', maximumCostCents: 100 });
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
  await ledger.reserve({ requestId: requestId(7), tier: 'flash', maximumCostCents: 150 });
  await assert.rejects(
    ledger.reserve({ requestId: requestId(8), tier: 'flash', maximumCostCents: 1 }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_cost_monthly_limit_reached',
  );
  await assert.rejects(
    ledger.confirm({ requestId: requestId(7), durationMs: 1, confirmedCostCents: 151 }),
    (error) => error instanceof AssistantContractError && error.code === 'assistant_cost_confirmed_cost_exceeds_reservation',
  );
});
