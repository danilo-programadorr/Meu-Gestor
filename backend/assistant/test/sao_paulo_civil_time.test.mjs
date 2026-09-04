import assert from 'node:assert/strict';
import test from 'node:test';

import {
  civilDateFromUtcInstant,
  validateCivilPeriod,
} from '../src/index.mjs';

test('hoje financeiro respeita a virada de dia em São Paulo', () => {
  assert.equal(civilDateFromUtcInstant('2026-09-03T02:59:59.999Z'), '2026-09-02');
  assert.equal(civilDateFromUtcInstant('2026-09-03T03:00:00.000Z'), '2026-09-03');
});

test('mês financeiro muda no limite civil, não no UTC', () => {
  assert.equal(civilDateFromUtcInstant('2026-09-01T02:59:59.999Z'), '2026-08-31');
  assert.equal(civilDateFromUtcInstant('2026-09-01T03:00:00.000Z'), '2026-09-01');
});

test('janela inclui o início e exclui o fim, inclusive em horário de verão histórico', () => {
  const period = validateCivilPeriod({
    timeZone: 'America/Sao_Paulo', startDate: '2018-11-03', endDateExclusive: '2018-11-05',
  });
  assert.equal(period.technicalWindow.start, '2018-11-03T03:00:00.000Z');
  assert.equal(period.technicalWindow.endExclusive, '2018-11-05T02:00:00.000Z');
  assert.equal(civilDateFromUtcInstant(period.technicalWindow.start), '2018-11-03');
  assert.equal(civilDateFromUtcInstant(period.technicalWindow.endExclusive), '2018-11-05');
});
