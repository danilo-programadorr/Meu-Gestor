import { deny } from './errors.mjs';

export const ASSISTANT_CIVIL_TIME_ZONE = 'America/Sao_Paulo';

const civilDatePattern = /^\d{4}-\d{2}-\d{2}$/;

const exactKeys = (value, keys) =>
  value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const formatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: ASSISTANT_CIVIL_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const parseCivilDate = (value) => {
  if (typeof value !== 'string' || !civilDatePattern.test(value)) throw deny('assistant_invalid_context');
  const [year, month, day] = value.split('-').map(Number);
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (probe.getUTCFullYear() !== year || probe.getUTCMonth() !== month - 1 || probe.getUTCDate() !== day) {
    throw deny('assistant_invalid_context');
  }
  return Object.freeze({ year, month, day, value });
};

const civilPartsForEpoch = (epochMs) => {
  const parts = formatter.formatToParts(new Date(epochMs));
  const values = Object.fromEntries(parts.filter((part) => part.type !== 'literal').map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
};

const nextCivilDate = (value) => {
  const parsed = parseCivilDate(value);
  const next = new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day + 1));
  return next.toISOString().slice(0, 10);
};

const asUtcIso = (value) => {
  if (typeof value !== 'string' || !value.endsWith('Z') || Number.isNaN(Date.parse(value))) {
    throw deny('assistant_invalid_context');
  }
  return new Date(value).toISOString();
};

/** Finds the first UTC instant belonging to a São Paulo civil date. The
 * search deliberately uses Intl rather than a fixed offset, so historical
 * daylight-saving transitions remain correct. */
const startOfCivilDateUtc = (value) => {
  const parsed = parseCivilDate(value);
  const center = Date.UTC(parsed.year, parsed.month - 1, parsed.day);
  let low = center - (48 * 60 * 60 * 1000);
  let high = center + (48 * 60 * 60 * 1000);
  if (civilPartsForEpoch(low) >= value || civilPartsForEpoch(high) < value) throw deny('assistant_invalid_context');
  while (low + 1 < high) {
    const middle = low + Math.floor((high - low) / 2);
    if (civilPartsForEpoch(middle) < value) low = middle;
    else high = middle;
  }
  if (civilPartsForEpoch(high) !== value) throw deny('assistant_invalid_context');
  return new Date(high).toISOString();
};

export const civilDateFromUtcInstant = (value) => {
  const instant = asUtcIso(value);
  return civilPartsForEpoch(Date.parse(instant));
};

/** A financial range is always [startDate, endDateExclusive) in São Paulo. */
export const validateCivilPeriod = (period) => {
  if (!exactKeys(period, ['timeZone', 'startDate', 'endDateExclusive'])
      || period.timeZone !== ASSISTANT_CIVIL_TIME_ZONE) {
    throw deny('assistant_invalid_context');
  }
  parseCivilDate(period.startDate);
  parseCivilDate(period.endDateExclusive);
  if (period.endDateExclusive <= period.startDate) throw deny('assistant_invalid_context');
  const start = startOfCivilDateUtc(period.startDate);
  const endExclusive = startOfCivilDateUtc(period.endDateExclusive);
  if (Date.parse(endExclusive) - Date.parse(start) > 366 * 24 * 60 * 60 * 1000) throw deny('assistant_invalid_context');
  return Object.freeze({
    timeZone: ASSISTANT_CIVIL_TIME_ZONE,
    startDate: period.startDate,
    endDateExclusive: period.endDateExclusive,
    technicalWindow: Object.freeze({ start, endExclusive }),
  });
};

export const civilPeriodForSingleDay = (date) => Object.freeze({
  timeZone: ASSISTANT_CIVIL_TIME_ZONE,
  startDate: date,
  endDateExclusive: nextCivilDate(date),
});

export const currentCivilDate = (now) => civilDateFromUtcInstant(asUtcIso(now.toISOString()));
