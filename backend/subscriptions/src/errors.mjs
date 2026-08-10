export class SubscriptionError extends Error {
  constructor(code, safeMessage, options = undefined) {
    super(safeMessage, options);
    this.name = 'SubscriptionError';
    this.code = code;
    this.safeMessage = safeMessage;
  }
}

export function deny(code = 'subscription_request_denied') {
  return new SubscriptionError(
    code,
    'Não foi possível confirmar o acesso Premium com segurança.',
  );
}

export function requireExactObject(value, fields, code) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw deny(code);
  }
  const keys = Object.keys(value).sort();
  const expected = [...fields].sort();
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) {
    throw deny(code);
  }
}

export function requireText(value, code, maximum = 256) {
  if (typeof value !== 'string' || value.length === 0 || value.trim() !== value || value.length > maximum) {
    throw deny(code);
  }
  return value;
}

export function requireUtcInstant(value, code, nullable = false) {
  if (nullable && value === null) return null;
  if (typeof value !== 'string' || !value.endsWith('Z')) throw deny(code);
  const date = new Date(value);
  if (Number.isNaN(date.valueOf()) || date.toISOString() !== value) throw deny(code);
  return date;
}
