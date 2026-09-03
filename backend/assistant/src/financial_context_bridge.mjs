import { deny } from './errors.mjs';

export const ASSISTANT_FINANCIAL_CONTEXT_POLICY_VERSION = 'assist-financial-context-v1';

const sourcePlans = Object.freeze([
  Object.freeze({ reader: 'accounts', sources: Object.freeze(['accounts']) }),
  Object.freeze({ reader: 'transactions', sources: Object.freeze(['transactions']) }),
  Object.freeze({ reader: 'commitments', sources: Object.freeze(['payables', 'receivables']) }),
  Object.freeze({ reader: 'financialCalendar', sources: Object.freeze(['financialCalendar']) }),
  Object.freeze({
    reader: 'investments',
    sources: Object.freeze(['investmentPortfolios', 'investmentAssets', 'investmentOperations']),
  }),
  Object.freeze({ reader: 'income', sources: Object.freeze(['investmentIncome']) }),
]);

const factKinds = new Set([
  'moneyCentsBrl',
  'integer',
  'basisPoints',
  'booleanValue',
  'utcInstant',
  'safeLabel',
]);

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const unsafeText = (value) =>
  typeof value !== 'string'
  || value.trim().length < 1
  || value.length > 80
  || /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(value)
  || /(?<!\d)(?:\d[ .-]?){11,19}(?!\d)/.test(value)
  || /(?:bearer\s+|api[_ -]?key|private[_ -]?key|password|senha|token\s*[:=])/i.test(value);

const asUtcIso = (value) => {
  if (typeof value !== 'string' || !value.endsWith('Z') || Number.isNaN(Date.parse(value))) {
    throw deny('assistant_invalid_context');
  }
  return new Date(value).toISOString();
};

const validateFact = (fact, allowedSources) => {
  if (!exactKeys(fact, ['source', 'kind', 'value'])
      || !allowedSources.has(fact.source)
      || !factKinds.has(fact.kind)) {
    throw deny('assistant_invalid_context');
  }
  const validValue = ['moneyCentsBrl', 'integer', 'basisPoints'].includes(fact.kind)
    ? Number.isSafeInteger(fact.value)
    : fact.kind === 'booleanValue'
      ? typeof fact.value === 'boolean'
      : fact.kind === 'utcInstant'
        ? typeof fact.value === 'string' && asUtcIso(fact.value) === fact.value
        : fact.kind === 'safeLabel'
          ? !unsafeText(fact.value)
          : false;
  if (!validValue) throw deny('assistant_invalid_context');
  return Object.freeze({ source: fact.source, kind: fact.kind, value: fact.value });
};

const validateSnapshot = (snapshot, plan) => {
  if (!exactKeys(snapshot, ['confirmed', 'facts'])
      || typeof snapshot.confirmed !== 'boolean'
      || !Array.isArray(snapshot.facts)) {
    throw deny('assistant_invalid_context');
  }
  const allowedSources = new Set(plan.sources);
  return Object.freeze({
    confirmed: snapshot.confirmed,
    facts: Object.freeze(snapshot.facts.map((fact) => validateFact(fact, allowedSources))),
  });
};

const validateActor = (actor) => {
  if (!exactKeys(actor, ['uid']) || typeof actor.uid !== 'string' || actor.uid.length < 1 || actor.uid.length > 256) {
    throw deny('assistant_unauthenticated');
  }
};

const validatePeriod = (period, generatedAt) => {
  if (!exactKeys(period, ['start', 'end'])) throw deny('assistant_invalid_context');
  const start = asUtcIso(period.start);
  const end = asUtcIso(period.end);
  if (Date.parse(end) < Date.parse(start)
      || Date.parse(generatedAt) < Date.parse(end)
      || Date.parse(end) - Date.parse(start) > 366 * 24 * 60 * 60 * 1000) {
    throw deny('assistant_invalid_context');
  }
  return Object.freeze({ start, end });
};

/**
 * Builds the only provider-facing financial context. Readers are injected
 * server-side contracts; this module has no network or persistence dependency
 * and cannot access application data by itself.
 */
export class AssistantFinancialContextBridge {
  constructor({ sourceReaders, clock = { now: () => new Date() } }) {
    if (!sourceReaders || typeof sourceReaders.readOwnSource !== 'function' || !clock || typeof clock.now !== 'function') {
      throw new TypeError('assistant_context_bridge_dependencies_required');
    }
    this.sourceReaders = sourceReaders;
    this.clock = clock;
  }

  async buildOwnConfirmedContext({ actor, period }) {
    validateActor(actor);
    const generatedAt = asUtcIso(this.clock.now().toISOString());
    const normalizedPeriod = validatePeriod(period, generatedAt);
    const facts = [];
    let aliasSequence = 0;

    for (const plan of sourcePlans) {
      const snapshot = validateSnapshot(
        await this.sourceReaders.readOwnSource({ ownerUid: actor.uid, reader: plan.reader, period: normalizedPeriod }),
        plan,
      );
      if (!snapshot.confirmed) {
        throw deny('assistant_invalid_context');
      }
      for (const fact of snapshot.facts) {
        aliasSequence += 1;
        facts.push(Object.freeze({
          evidenceId: `ev_${fact.source.toLowerCase()}_${String(aliasSequence).padStart(3, '0')}`,
          source: fact.source,
          kind: fact.kind,
          value: fact.value,
        }));
      }
    }

    return Object.freeze({
      ownerVerified: true,
      isFromServer: true,
      hasPendingWrites: false,
      generatedAt,
      period: normalizedPeriod,
      facts: Object.freeze(facts),
      missingSources: Object.freeze([]),
    });
  }
}

export const ASSISTANT_FINANCIAL_CONTEXT_SOURCE_READERS = Object.freeze(
  sourcePlans.map((plan) => plan.reader),
);
