import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const require = createRequire(import.meta.url);

test('production artifact keeps the required Admin and Functions entry points', async () => {
  await import('firebase-admin/app');
  await import('firebase-admin/firestore');
  await import('firebase-functions/v2/https');
});

test('production artifact omits unused optional Storage and uuid packages', () => {
  for (const forbiddenModule of ['@google-cloud/storage', 'uuid']) {
    assert.throws(
      () => require.resolve(forbiddenModule),
      { code: 'MODULE_NOT_FOUND' },
      `${forbiddenModule} must not be present in the production artifact`,
    );
  }
});
