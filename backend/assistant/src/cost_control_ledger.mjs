import { randomUUID } from 'node:crypto';

import { deny } from './errors.mjs';

export const ASSISTANT_COST_CONTROL_POLICY_VERSION = 'assist-cost-control-v1';
export const ASSISTANT_COST_CONTROL_LIMITS = Object.freeze({
  dailyLimitCents: 500,
  monthlyOperationalLimitCents: 4_500,
});

export const ASSISTANT_COST_LEDGER_STATE = Object.freeze({
  reserved: 'reserved',
  confirmed: 'confirmed',
});

const exactKeys = (value, keys) => value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const isPositiveCents = (value) => Number.isSafeInteger(value) && value > 0;
const isDuration = (value) => Number.isSafeInteger(value) && value >= 0;
const isTier = (value) => value === 'flash' || value === 'pro';
const isRequestId = (value) => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(value);
const isDayKey = (value) => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
const isMonthKey = (value) => typeof value === 'string' && /^\d{4}-\d{2}$/.test(value);

const clone = (value) => structuredClone(value);

const assertRecord = (record) => {
  if (!exactKeys(record, ['confirmedCostCents', 'durationMs', 'requestId', 'reservedCostCents', 'state', 'tier'])
      || !isRequestId(record.requestId)
      || !isTier(record.tier)
      || !isPositiveCents(record.reservedCostCents)
      || (record.confirmedCostCents !== null && !isPositiveCents(record.confirmedCostCents))
      || (record.durationMs !== null && !isDuration(record.durationMs))
      || !Object.values(ASSISTANT_COST_LEDGER_STATE).includes(record.state)
      || (record.state === ASSISTANT_COST_LEDGER_STATE.reserved
        && (record.confirmedCostCents !== null || record.durationMs !== null))
      || (record.state === ASSISTANT_COST_LEDGER_STATE.confirmed
        && (record.confirmedCostCents === null || record.durationMs === null
          || record.confirmedCostCents > record.reservedCostCents))) {
    throw deny('assistant_cost_ledger_inconsistent');
  }
};

const assertCounter = (counter) => {
  if (!exactKeys(counter, ['confirmedCostCents', 'reservedCostCents'])
      || !Number.isSafeInteger(counter.confirmedCostCents)
      || !Number.isSafeInteger(counter.reservedCostCents)
      || counter.confirmedCostCents < 0
      || counter.reservedCostCents < 0) {
    throw deny('assistant_cost_ledger_inconsistent');
  }
};

const assertReservationPeriod = (period) => {
  if (!exactKeys(period, ['dailyKey', 'monthlyKey'])
      || !isDayKey(period.dailyKey)
      || !isMonthKey(period.monthlyKey)) {
    throw deny('assistant_cost_ledger_inconsistent');
  }
};

const emptyCounter = () => ({ confirmedCostCents: 0, reservedCostCents: 0 });
const counterTotal = (counter) => counter.confirmedCostCents + counter.reservedCostCents;
const dayKey = (now) => now.toISOString().slice(0, 10);
const monthKey = (now) => now.toISOString().slice(0, 7);

export const createAssistantCostRequestId = () => randomUUID();

/**
 * Deterministic persistence fake used by the local contract tests. Production
 * adapters must implement the same transaction contract against the dedicated
 * control database; this fake never stores user or conversation information.
 */
export class InMemoryAssistantCostLedgerStore {
  constructor(snapshot = undefined) {
    this.state = snapshot === undefined ? {
      daily: {}, monthly: {}, periods: {}, records: {},
    } : clone(snapshot);
    this.transactionTail = Promise.resolve();
    this.#assertState(this.state);
  }

  async runTransaction(callback) {
    const previous = this.transactionTail;
    let release;
    this.transactionTail = new Promise((resolve) => { release = resolve; });
    await previous;
    try {
      const draft = clone(this.state);
      const result = await callback(draft);
      this.#assertState(draft);
      this.state = draft;
      return clone(result);
    } finally {
      release();
    }
  }

  snapshot() {
    return clone(this.state);
  }

  #assertState(state) {
    if (!exactKeys(state, ['daily', 'monthly', 'periods', 'records'])
        || !state.daily || !state.monthly || !state.periods || !state.records
        || Array.isArray(state.daily) || Array.isArray(state.monthly)
        || Array.isArray(state.periods) || Array.isArray(state.records)) {
      throw deny('assistant_cost_ledger_inconsistent');
    }
    Object.values(state.daily).forEach(assertCounter);
    Object.values(state.monthly).forEach(assertCounter);
    Object.values(state.records).forEach(assertRecord);
    Object.values(state.periods).forEach(assertReservationPeriod);
    const recordIds = Object.keys(state.records).sort().join('|');
    const periodIds = Object.keys(state.periods).sort().join('|');
    if (recordIds !== periodIds) throw deny('assistant_cost_ledger_inconsistent');
  }
}

const assertLimits = (limits) => {
  if (!exactKeys(limits, ['dailyLimitCents', 'monthlyOperationalLimitCents'])
      || !isPositiveCents(limits.dailyLimitCents)
      || !isPositiveCents(limits.monthlyOperationalLimitCents)) {
    throw new TypeError('assistant_cost_limits_invalid');
  }
};

export class AssistantCostControlLedger {
  constructor({ store, clock, limits = ASSISTANT_COST_CONTROL_LIMITS }) {
    if (!store || typeof store.runTransaction !== 'function' || typeof clock !== 'function') {
      throw new TypeError('assistant_cost_ledger_dependency_invalid');
    }
    assertLimits(limits);
    this.store = store;
    this.clock = clock;
    this.limits = Object.freeze({ ...limits });
  }

  async reserve({ maximumCostCents, requestId, tier }) {
    if (!isRequestId(requestId) || !isTier(tier) || !isPositiveCents(maximumCostCents)) {
      throw new TypeError('assistant_cost_reservation_invalid');
    }
    const now = this.#serverNow();
    const currentDay = dayKey(now);
    const currentMonth = monthKey(now);
    return this.store.runTransaction((state) => {
      const existing = state.records[requestId];
      if (existing) {
        assertRecord(existing);
        assertReservationPeriod(state.periods[requestId]);
        if (existing.tier !== tier || existing.reservedCostCents !== maximumCostCents) {
          throw deny('assistant_cost_request_id_conflict');
        }
        return existing;
      }

      const daily = state.daily[currentDay] ?? emptyCounter();
      const monthly = state.monthly[currentMonth] ?? emptyCounter();
      assertCounter(daily);
      assertCounter(monthly);
      if (counterTotal(daily) + maximumCostCents > this.limits.dailyLimitCents) {
        throw deny('assistant_cost_daily_limit_reached');
      }
      if (counterTotal(monthly) + maximumCostCents > this.limits.monthlyOperationalLimitCents) {
        throw deny('assistant_cost_monthly_limit_reached');
      }

      daily.reservedCostCents += maximumCostCents;
      monthly.reservedCostCents += maximumCostCents;
      state.daily[currentDay] = daily;
      state.monthly[currentMonth] = monthly;
      state.periods[requestId] = {
        dailyKey: currentDay,
        monthlyKey: currentMonth,
      };
      const record = {
        requestId,
        tier,
        durationMs: null,
        reservedCostCents: maximumCostCents,
        confirmedCostCents: null,
        state: ASSISTANT_COST_LEDGER_STATE.reserved,
      };
      state.records[requestId] = record;
      return record;
    });
  }

  async confirm({ confirmedCostCents, durationMs, requestId }) {
    if (!isRequestId(requestId) || !isPositiveCents(confirmedCostCents) || !isDuration(durationMs)) {
      throw new TypeError('assistant_cost_confirmation_invalid');
    }
    this.#serverNow();
    return this.store.runTransaction((state) => {
      const record = state.records[requestId];
      if (!record) throw deny('assistant_cost_reservation_required');
      assertRecord(record);
      const reservationPeriod = state.periods[requestId];
      assertReservationPeriod(reservationPeriod);
      if (record.state === ASSISTANT_COST_LEDGER_STATE.confirmed) {
        if (record.confirmedCostCents !== confirmedCostCents || record.durationMs !== durationMs) {
          throw deny('assistant_cost_request_id_conflict');
        }
        return record;
      }
      if (confirmedCostCents > record.reservedCostCents) throw deny('assistant_cost_confirmed_cost_exceeds_reservation');

      const daily = state.daily[reservationPeriod.dailyKey];
      const monthly = state.monthly[reservationPeriod.monthlyKey];
      if (!daily || !monthly) throw deny('assistant_cost_ledger_inconsistent');
      assertCounter(daily);
      assertCounter(monthly);
      if (daily.reservedCostCents < record.reservedCostCents
          || monthly.reservedCostCents < record.reservedCostCents) {
        throw deny('assistant_cost_ledger_inconsistent');
      }

      // Unused capacity is released only after a measured cost is confirmed.
      daily.reservedCostCents -= record.reservedCostCents;
      monthly.reservedCostCents -= record.reservedCostCents;
      daily.confirmedCostCents += confirmedCostCents;
      monthly.confirmedCostCents += confirmedCostCents;
      record.confirmedCostCents = confirmedCostCents;
      record.durationMs = durationMs;
      record.state = ASSISTANT_COST_LEDGER_STATE.confirmed;
      return record;
    });
  }

  #serverNow() {
    const now = this.clock();
    if (!(now instanceof Date) || Number.isNaN(now.getTime())) throw deny('assistant_cost_server_time_invalid');
    return now;
  }
}
