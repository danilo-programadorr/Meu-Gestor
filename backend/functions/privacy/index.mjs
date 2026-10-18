import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  FingerprintOperationIdGenerator,
  ReceiptIdGenerator,
} from '../../privacy/src/gateways.mjs';
import { createAssistantUsagePrivacyTarget } from './src/assistant_usage_privacy_target.mjs';
import { createFirebasePrivacyAdapters } from './src/firebase_adapters.mjs';
import { createFirebasePrivacyCallables } from './src/firebase_callables.mjs';
import { FirestorePrivacyStorage } from './src/firestore_privacy_storage.mjs';
import { PRIVACY_FUNCTION_OPTIONS, PRIVACY_WORKER_OPTIONS } from './src/function_options.mjs';
import { createPrivacyOperationWorker } from './src/privacy_worker.mjs';
import { createPrivacyRuntime } from './src/privacy_runtime.mjs';

const app = getApps().length === 0 ? initializeApp() : getApps()[0];
const firestore = getFirestore(app);
const assistantControls = getFirestore(app, 'assistant-controls-dev');
const adapters = createFirebasePrivacyAdapters({ firestore, auth: getAuth(app) });
const processor = createPrivacyRuntime({
  storage: new FirestorePrivacyStorage({
    firestore,
    Timestamp,
    externalTargets: {
      assistantUsageLedger: createAssistantUsagePrivacyTarget({ firestore: assistantControls }),
    },
  }),
  adapters,
  receiptIdGenerator: new ReceiptIdGenerator(),
  operationIdGenerator: new FingerprintOperationIdGenerator(),
  batchSize: 25,
});
const callables = createFirebasePrivacyCallables({
  onCall,
  HttpsError,
  processor,
  profileReader: adapters.profileReader,
  clock: adapters.clock,
  options: PRIVACY_FUNCTION_OPTIONS,
  logger: console,
});

export const preparePrivacyOperation = callables.preparePrivacyOperation;
export const confirmPrivacyOperation = callables.confirmPrivacyOperation;
export const getPrivacyOperationStatus = callables.getPrivacyOperationStatus;
export const processPrivacyOperation = createPrivacyOperationWorker({
  onDocumentWritten,
  options: PRIVACY_WORKER_OPTIONS,
  processor,
  logger: console,
});
