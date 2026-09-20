/**
 * Responsabilidade: compara cada grandeza escrita pelo modelo com fatos
 * tipados e confirmados, usando inteiros exatos e sem tolerância aproximada.
 */
const comparableKinds = new Set([
  'moneyCentsBrl',
  'integer',
  'basisPoints',
  'utcInstant',
  'civilDate',
]);

const brazilianNumber = String.raw`(?:(?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{1,2})?)`;
const numericMentionPattern = new RegExp([
  String.raw`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z`,
  String.raw`\d{4}-\d{2}-\d{2}`,
  String.raw`\d{2}\/\d{2}\/\d{4}`,
  String.raw`(?:-\s*)?R\$\s*-?\s*${brazilianNumber}`,
  String.raw`-?${brazilianNumber}\s*(?:reais?|centavos?)`,
  String.raw`-?${brazilianNumber}\s*(?:pontos?(?:\s*-\s*|\s+)base|bps?)`,
  String.raw`-?${brazilianNumber}\s*%`,
  String.raw`-?${brazilianNumber}`,
].join('|'), 'giu');

const parseBrazilianDecimal = (raw, scale) => {
  const negative = raw.includes('-');
  const numeric = raw.replace(/[^\d.,]/gu, '');
  const [integerPart, fractionPart, extra] = numeric.split(',');
  if (extra !== undefined || integerPart.length === 0
      || (integerPart.includes('.') && !/^\d{1,3}(?:\.\d{3})+$/u.test(integerPart))
      || (!integerPart.includes('.') && !/^\d+$/u.test(integerPart))
      || (scale === 0 && fractionPart !== undefined)
      || (fractionPart !== undefined && (!/^\d+$/u.test(fractionPart) || fractionPart.length > scale))) {
    return null;
  }
  const integerDigits = integerPart.replaceAll('.', '');
  const fractionDigits = (fractionPart ?? '').padEnd(scale, '0');
  const factor = 10n ** BigInt(scale);
  const value = (BigInt(integerDigits) * factor) + BigInt(fractionDigits || '0');
  return negative ? -value : value;
};

const parseCivilDate = (raw) => {
  const iso = /^\d{4}-\d{2}-\d{2}$/u.test(raw)
    ? raw
    : /^(?<day>\d{2})\/(?<month>\d{2})\/(?<year>\d{4})$/u.exec(raw)?.groups;
  const value = typeof iso === 'string'
    ? iso
    : iso
      ? `${iso.year}-${iso.month}-${iso.day}`
      : null;
  if (value === null) return null;
  const instant = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(instant.getTime()) || instant.toISOString().slice(0, 10) !== value
    ? null
    : value;
};

const saoPauloCivilDate = (instant) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(instant));
  const read = (type) => parts.find((part) => part.type === type)?.value;
  return `${read('year')}-${read('month')}-${read('day')}`;
};

const classifyMention = (raw, index) => {
  if (/^\d{4}-\d{2}-\d{2}T/iu.test(raw)) {
    const parsed = Date.parse(raw);
    return { kind: 'utcInstant', value: Number.isNaN(parsed) ? null : new Date(parsed).toISOString(), raw, index };
  }
  if (/^(?:\d{4}-\d{2}-\d{2}|\d{2}\/\d{2}\/\d{4})$/u.test(raw)) {
    return { kind: 'civilDate', value: parseCivilDate(raw), raw, index };
  }
  if (/R\$/iu.test(raw) || /reais?$/iu.test(raw)) {
    return { kind: 'moneyCentsBrl', value: parseBrazilianDecimal(raw, 2), raw, index };
  }
  if (/centavos?$/iu.test(raw)) {
    return { kind: 'moneyCentsBrl', value: parseBrazilianDecimal(raw, 0), raw, index };
  }
  if (/(?:pontos?(?:\s*-\s*|\s+)base|bps?)$/iu.test(raw)) {
    return { kind: 'basisPoints', value: parseBrazilianDecimal(raw, 0), raw, index };
  }
  if (/%$/u.test(raw)) {
    return { kind: 'basisPoints', value: parseBrazilianDecimal(raw, 2), raw, index };
  }
  return { kind: 'integer', value: parseBrazilianDecimal(raw, 0), raw, index };
};

const extractMentions = (text) => [...text.matchAll(numericMentionPattern)]
  .map((match) => {
    const mention = classifyMention(match[0], match.index);
    const before = text[match.index - 1] ?? '';
    const after = text[match.index + match[0].length] ?? '';
    return /[\p{L}\p{N}_]/u.test(before) || /[\p{L}\p{N}_]/u.test(after)
      ? { ...mention, value: null }
      : mention;
  });

const factMatches = (fact, mention) => {
  if (mention.value === null) return false;
  if (fact.kind === mention.kind && ['moneyCentsBrl', 'integer', 'basisPoints'].includes(fact.kind)) {
    return BigInt(fact.value) === mention.value;
  }
  if (fact.kind === 'civilDate' && mention.kind === 'civilDate') {
    return fact.value === mention.value;
  }
  if (fact.kind === 'utcInstant' && mention.kind === 'utcInstant') {
    return fact.value === mention.value;
  }
  return fact.kind === 'utcInstant'
    && mention.kind === 'civilDate'
    && saoPauloCivilDate(fact.value) === mention.value;
};

const formatBrlCents = (value) => {
  const cents = BigInt(value);
  const negative = cents < 0n;
  const absolute = negative ? -cents : cents;
  const integerDigits = (absolute / 100n).toString();
  const groups = [];
  for (let end = integerDigits.length; end > 0; end -= 3) {
    groups.unshift(integerDigits.slice(Math.max(0, end - 3), end));
  }
  const fraction = (absolute % 100n).toString().padStart(2, '0');
  return `${negative ? '-' : ''}R$ ${groups.join('.')},${fraction}`;
};

/**
 * Valida todas as menções numéricas. Somente dinheiro comprovado é
 * reformatado, sempre a partir do valor inteiro do fato server-side.
 */
export const validateAndCanonicalizeGroundedText = ({ text, facts }) => {
  const mentions = extractMentions(text);
  if (mentions.length === 0) return Object.freeze({ outcome: 'passed', text });
  const comparableFacts = facts.filter((fact) => comparableKinds.has(fact.kind));
  if (comparableFacts.length === 0) {
    return Object.freeze({ outcome: 'evidence_non_numeric' });
  }
  const replacements = [];
  for (const mention of mentions) {
    const matchingFact = comparableFacts.find((fact) => factMatches(fact, mention));
    if (!matchingFact) return Object.freeze({ outcome: 'value_mismatch' });
    if (mention.kind === 'moneyCentsBrl') {
      replacements.push({
        start: mention.index,
        end: mention.index + mention.raw.length,
        value: formatBrlCents(matchingFact.value),
      });
    }
  }
  let canonical = text;
  for (const replacement of replacements.reverse()) {
    canonical = `${canonical.slice(0, replacement.start)}${replacement.value}${canonical.slice(replacement.end)}`;
  }
  return Object.freeze({ outcome: 'passed', text: canonical });
};
