/**
 * Responsabilidade: define e valida o ledger idempotente de reserva de custo
 * sem registrar prompt, resposta, identidade ou dado financeiro.
 */
import { randomUUID } from 'node:crypto';
import { createHash } from 'node:crypto';

import { deny } from './errors.mjs';

export const ASSISTANT_COST_CONTROL_POLICY_VERSION = 'assist-cost-control-v1';
export const ASSISTANT_COST_CONTROL_LIMITS = Object.freeze({
  dailyLimitCents: 500,
  monthlyOperationalLimitCents: 4_500,
});

export const ASSISTANT_OWNER_USAGE_LIMITS = Object.freeze({
  costUnitsPerWindow: 32,
  proCallsPerWindow: 4,
  flashCostUnits: 1,
  proCostUnits: 8,
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
const isOwnerScope = (value) => typeof value === 'string' && /^[a-f0-9]{64}$/iu.test(value);
const isUsageUnits = (value) => Number.isSafeInteger(value) && value > 0;

const clone = (value) => structuredClone(value);

const assertRecord = (record) => {
  if (!exactKeys(record, ['confirmedCostCents', 'durationMs', 'ownerScope', 'requestId', 'reservedCostCents', 'state', 'tier', 'usageCostUnits'])
      || !isRequestId(record.requestId)
      || !isTier(record.tier)
      || !isOwnerScope(record.ownerScope)
      || !isUsageUnits(record.usageCostUnits)
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

const assertOwnerUsage = (usage) => {
  if (!exactKeys(usage, ['costUnitsInWindow', 'proCallsInWindow', 'windowDay'])
      || !isDayKey(usage.windowDay)
      || !Number.isSafeInteger(usage.costUnitsInWindow)
      || !Number.isSafeInteger(usage.proCallsInWindow)
      || usage.costUnitsInWindow < 0
      || usage.proCallsInWindow < 0) {
    throw deny('assistant_usage_record_invalid');
  }
};

const assertOwnerUsageMap = (usage) => {
  if (!usage || typeof usage !== 'object' || Array.isArray(usage)) {
    throw deny('assistant_usage_record_invalid');
  }
  for (const [ownerScope, counters] of Object.entries(usage)) {
    if (!isOwnerScope(ownerScope)) throw deny('assistant_usage_record_invalid');
    assertOwnerUsage(counters);
  }
};

const emptyCounter = () => ({ confirmedCostCents: 0, reservedCostCents: 0 });
const emptyOwnerUsage = (windowDay) => ({ windowDay, costUnitsInWindow: 0, proCallsInWindow: 0 });
const counterTotal = (counter) => counter.confirmedCostCents + counter.reservedCostCents;
const dayKey = (now) => now.toISOString().slice(0, 10);
const monthKey = (now) => now.toISOString().slice(0, 7);

export const createAssistantCostRequestId = () => randomUUID();

/** Deriva um escopo pseudonimizado exclusivamente do UID autenticado. */
export const createAssistantOwnerScope = (uid) => {
  if (typeof uid !== 'string' || uid.trim() !== uid || uid.length === 0 || uid.length > 128) {
    throw new TypeError('assistant_owner_scope_invalid');
  }
  return createHash('sha256').update(`assistant-owner-usage-v1:${uid}`, 'utf8').digest('hex');
};

const normalizeState = (state) => {
  if (!state || typeof state !== 'object' || Array.isArray(state)) {
    throw deny('assistant_cost_ledger_inconsistent');
  }
  const keys = Object.keys(state).sort().join('|');
  if (keys === 'daily|monthly|periods|records') {
    return { ...state, usage: {} };
  }
  if (keys !== 'daily|monthly|periods|records|usage') {
    throw deny('assistant_cost_ledger_inconsistent');
  }
  return state;
};

/** Normaliza somente o esquema legado do ledger, sem criar uso de proprietário. */
export const normalizeAssistantCostLedgerState = (state) => normalizeState(state);

/**
 * Deterministic persistence fake used by the local contract tests. Production
 * adapters must implement the same transaction contract against the dedicated
 * control database; this fake never stores user or conversation information.
 */
export class InMemoryAssistantCostLedgerStore {
  constructor(snapshot = undefined) {
    this.state = snapshot === undefined ? {
      daily: {}, monthly: {}, periods: {}, records: {}, usage: {},
    } : normalizeState(clone(snapshot));
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
    if (!exactKeys(state, ['daily', 'monthly', 'periods', 'records', 'usage'])
        || !state.daily || !state.monthly || !state.periods || !state.records || !state.usage
        || Array.isArray(state.daily) || Array.isArray(state.monthly)
        || Array.isArray(state.periods) || Array.isArray(state.records) || Array.isArray(state.usage)) {
      throw deny('assistant_cost_ledger_inconsistent');
    }
    Object.values(state.daily).forEach(assertCounter);
    Object.values(state.monthly).forEach(assertCounter);
    Object.values(state.records).forEach(assertRecord);
    Object.values(state.periods).forEach(assertReservationPeriod);
    assertOwnerUsageMap(state.usage);
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
  constructor({ store, clock, limits = ASSISTANT_COST_CONTROL_LIMITS, usageLimits = ASSISTANT_OWNER_USAGE_LIMITS }) {
    if (!store || typeof store.runTransaction !== 'function' || typeof clock !== 'function') {
      throw new TypeError('assistant_cost_ledger_dependency_invalid');
    }
    assertLimits(limits);
    if (!exactKeys(usageLimits, ['costUnitsPerWindow', 'flashCostUnits', 'proCallsPerWindow', 'proCostUnits'])
        || !Object.values(usageLimits).every(isUsageUnits)) {
      throw new TypeError('assistant_usage_limits_invalid');
    }
    this.store = store;
    this.clock = clock;
    this.limits = Object.freeze({ ...limits });
    this.usageLimits = Object.freeze({ ...usageLimits });
  }

  async readUsage({ ownerScope }) {
    if (!isOwnerScope(ownerScope)) throw new TypeError('assistant_owner_scope_invalid');
    const currentDay = dayKey(this.#serverNow());
    return this.store.runTransaction((state) => {
      const normalized = normalizeState(state);
      if (normalized !== state) Object.assign(state, normalized);
      const currentUsage = this.#readCurrentOwnerUsage(state, ownerScope, currentDay);
      return Object.freeze({
        costUnitsInWindow: currentUsage.costUnitsInWindow,
        proCallsInWindow: currentUsage.proCallsInWindow,
      });
    });
  }

  async reserve({ maximumCostCents, ownerScope, requestId, tier, usageCostUnits }) {
    if (!isRequestId(requestId) || !isTier(tier) || !isPositiveCents(maximumCostCents)
        || !isOwnerScope(ownerScope) || !isUsageUnits(usageCostUnits)
        || usageCostUnits !== this.#usageCostForTier(tier)) {
      throw new TypeError('assistant_cost_reservation_invalid');
    }
    const now = this.#serverNow();
    const currentDay = dayKey(now);
    const currentMonth = monthKey(now);
    return this.store.runTransaction((state) => {
      const normalized = normalizeState(state);
      if (normalized !== state) Object.assign(state, normalized);
      const existing = state.records[requestId];
      if (existing) {
        assertRecord(existing);
        assertReservationPeriod(state.periods[requestId]);
        if (existing.tier !== tier || existing.reservedCostCents !== maximumCostCents
            || existing.ownerScope !== ownerScope || existing.usageCostUnits !== usageCostUnits) {
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

      const ownerUsage = this.#readCurrentOwnerUsage(state, ownerScope, currentDay);
      if (ownerUsage.costUnitsInWindow + usageCostUnits > this.usageLimits.costUnitsPerWindow) {
        throw deny('assistant_usage_limit_reached');
      }
      if (tier === 'pro' && ownerUsage.proCallsInWindow >= this.usageLimits.proCallsPerWindow) {
        throw deny('assistant_pro_limit_reached');
      }

      daily.reservedCostCents += maximumCostCents;
      monthly.reservedCostCents += maximumCostCents;
      ownerUsage.costUnitsInWindow += usageCostUnits;
      if (tier === 'pro') ownerUsage.proCallsInWindow += 1;
      state.daily[currentDay] = daily;
      state.monthly[currentMonth] = monthly;
      state.periods[requestId] = {
        dailyKey: currentDay,
        monthlyKey: currentMonth,
      };
      const record = {
        requestId,
        tier,
        ownerScope,
        usageCostUnits,
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
      const normalized = normalizeState(state);
      if (normalized !== state) Object.assign(state, normalized);
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

  #readCurrentOwnerUsage(state, ownerScope, currentDay) {
    const stored = state.usage[ownerScope];
    if (stored === undefined) throw deny('assistant_usage_record_required');
    assertOwnerUsage(stored);
    if (stored.windowDay !== currentDay) {
      state.usage[ownerScope] = emptyOwnerUsage(currentDay);
    }
    return state.usage[ownerScope];
  }

  #usageCostForTier(tier) {
    return tier === 'flash'
      ? this.usageLimits.flashCostUnits
      : this.usageLimits.proCostUnits;
  }
}
