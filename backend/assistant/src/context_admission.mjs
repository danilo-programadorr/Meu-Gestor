import { deny } from './errors.mjs';
import { ASSISTANT_CIVIL_TIME_ZONE, validateCivilPeriod } from './sao_paulo_civil_time.mjs';

export const ASSISTANT_CONTEXT_ADMISSION_POLICY_VERSION = 'assist-context-admission-v1';

const permittedSources = new Set([
  'accounts', 'transactions', 'payables', 'receivables', 'financialCalendar',
  'investmentPortfolios', 'investmentAssets', 'investmentOperations', 'investmentIncome',
]);
const maximumSources = 9;
const maximumDays = 366;

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

/**
 * Produces a non-identifying, finite plan before any source reader can run.
 * This is intentionally a server-side contract: it accepts no client UID,
 * e-mail, aliases, persistent IDs, values or provider instructions.
 */
export const admitOwnFinancialContext = ({ authorization, scope, civilPeriod }) => {
  if (!authorization?.authenticated || authorization.financialPrivacyActive === true) {
    throw deny('assistant_financial_privacy_active');
  }
  if (!exactKeys(scope, ['kind', 'sources'])
      || scope.kind !== 'own_financial_information'
      || !Array.isArray(scope.sources)
      || scope.sources.length === 0
      || scope.sources.length > maximumSources
      || new Set(scope.sources).size !== scope.sources.length
      || scope.sources.some((source) => !permittedSources.has(source))) {
    throw deny('assistant_context_admission_denied');
  }
  let period;
  try {
    period = validateCivilPeriod(civilPeriod);
  } catch {
    throw deny('assistant_context_admission_denied');
  }
  const duration = Date.parse(period.technicalWindow.endExclusive) - Date.parse(period.technicalWindow.start);
  if (duration <= 0 || duration > maximumDays * 24 * 60 * 60 * 1000) {
    throw deny('assistant_context_admission_denied');
  }
  return Object.freeze({
    policyVersion: ASSISTANT_CONTEXT_ADMISSION_POLICY_VERSION,
    ownerOnly: true,
    timeZone: ASSISTANT_CIVIL_TIME_ZONE,
    scope: Object.freeze({ kind: scope.kind, sources: Object.freeze([...scope.sources]) }),
    civilPeriod: Object.freeze({
      timeZone: period.timeZone,
      startDate: period.startDate,
      endDateExclusive: period.endDateExclusive,
    }),
    technicalWindow: period.technicalWindow,
  });
};

export const DEFAULT_ASSISTANT_CONTEXT_SCOPE = Object.freeze({
  kind: 'own_financial_information',
  sources: Object.freeze([
    'accounts', 'transactions', 'payables', 'receivables', 'financialCalendar',
    'investmentPortfolios', 'investmentAssets', 'investmentOperations', 'investmentIncome',
  ]),
});
