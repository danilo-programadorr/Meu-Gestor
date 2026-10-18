import assert from 'node:assert/strict';
import test from 'node:test';

import { createPrivacyOperationWorker } from '../src/privacy_worker.mjs';

test('worker ignora prepare/falha e processa somente operação interna pronta', async () => {
  const calls = [];
  let handler;
  createPrivacyOperationWorker({
    onDocumentWritten: (options, value) => {
      assert.equal(options.document, 'users/{ownerId}/privacyOperations/current');
      handler = value;
      return value;
    },
    options: { retry: true },
    processor: {
      process: async (request) => {
        calls.push(request);
        return { state: 'locked' };
      },
    },
    logger: { info() {} },
  });
  await handler(event('prepared'));
  await handler(event('failed'));
  await handler(event('confirmed'));
  assert.deepEqual(calls, [{
    ownerId: 'synthetic-owner',
    operationId: 'privacy-operation-synthetic-0001',
  }]);
});

test('worker preserva retry sem propagar erro bruto ou identidade ao log', async () => {
  let handler;
  const logs = [];
  createPrivacyOperationWorker({
    onDocumentWritten: (_options, value) => {
      handler = value;
      return value;
    },
    options: { retry: true },
    processor: {
      process: async () => {
        throw new Error('raw-error-containing-synthetic-owner');
      },
    },
    logger: {
      info(eventName, fields) {
        logs.push({ eventName, fields });
      },
    },
  });
  await assert.rejects(
    () => handler(event('confirmed')),
    (error) => error?.message === 'privacy_worker_retryable_failure' &&
      !error.message.includes('synthetic-owner'),
  );
  assert.deepEqual(logs, [{
    eventName: 'privacy_worker_transition',
    fields: { stage: 'failed', state: 'retryable' },
  }]);
});

const event = (state) => ({
  params: { ownerId: 'synthetic-owner' },
  data: {
    after: {
      exists: true,
      data: () => ({
        operationId: 'privacy-operation-synthetic-0001',
        state,
      }),
    },
  },
});
