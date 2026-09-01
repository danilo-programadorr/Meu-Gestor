import assert from 'node:assert/strict';
import test from 'node:test';

import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  terminate,
} from 'firebase/firestore';

const app = initializeApp({
  apiKey: 'synthetic-test-key',
  projectId: 'demo-meu-gestor-financeiro',
}, 'assistant-controls-deny-all-test');
const database = getFirestore(app, 'assistant-controls-dev');
connectFirestoreEmulator(database, '127.0.0.1', 8080);
const reference = doc(database, '_assistantCostLedger/synthetic-request');

test('banco nomeado assistant-controls-dev nega leitura e escrita de qualquer cliente', async () => {
  await assert.rejects(getDoc(reference));
  await assert.rejects(setDoc(reference, {
    requestId: '00000000-0000-4000-8000-000000000001',
    tier: 'flash',
  }));
});

test.after(async () => {
  await terminate(database);
  await deleteApp(app);
});
