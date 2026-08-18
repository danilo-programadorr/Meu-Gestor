import assert from 'node:assert/strict';
import test from 'node:test';
import { mapProviderQuote, QuoteService, QuoteStatus } from '../src/index.mjs';

const at = (value) => new Date(value);
const valid = Object.freeze({ ticker: 'PETR4', assetType: 'stock', currencyCode: 'BRL', priceScaled: 32123456, variationBasisPoints: 125, observedAt: '2026-08-18T12:00:00.000Z', status: 'delayed' });

test('strict mapper rejects zero price, unknown fields, currency substitutes and missing time', () => {
  assert.throws(() => mapProviderQuote({ ...valid, priceScaled: 0 }, { capturedAt: at('2026-08-18T12:01:00Z'), staleAfter: at('2026-08-18T12:20:00Z') }));
  assert.throws(() => mapProviderQuote({ ...valid, currencyCode: 'USD' }, { capturedAt: at('2026-08-18T12:01:00Z'), staleAfter: at('2026-08-18T12:20:00Z') }));
  assert.throws(() => mapProviderQuote({ ...valid, observedAt: '' }, { capturedAt: at('2026-08-18T12:01:00Z'), staleAfter: at('2026-08-18T12:20:00Z') }));
});

test('global cache deduplicates ticker batches and does not let an older answer replace a newer snapshot', async () => {
  let now = at('2026-08-18T12:01:00Z');
  const responses = [
    [{ ...valid, observedAt: '2026-08-18T12:00:00Z' }],
    [{ ...valid, priceScaled: 30000000, observedAt: '2026-08-18T11:00:00Z' }],
  ];
  const service = new QuoteService({ gateway: { fetchBatch: async () => responses.shift() }, clock: () => now });
  await service.refresh(['PETR4', 'PETR4']);
  now = at('2026-08-18T12:02:00Z');
  await service.refresh(['PETR4']);
  assert.equal(service.read(['PETR4'])[0].priceScaled, 32123456);
});

test('failure uses circuit breaker and returns unavailable without a fake price', async () => {
  let calls = 0;
  const service = new QuoteService({
    gateway: { fetchBatch: async () => { calls += 1; throw new Error('offline'); } },
    clock: () => at('2026-08-18T12:01:00Z'),
  });
  const first = await service.refresh(['HGLG11']);
  const second = await service.refresh(['HGLG11']);
  assert.equal(calls, 1);
  assert.equal(first[0].status, QuoteStatus.UNAVAILABLE);
  assert.equal(second[0].priceScaled, 0);
});
