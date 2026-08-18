import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { DeterministicReceiptIdGenerator } from '../../privacy/src/gateways.mjs';
import { createFirebasePrivacyAdapters } from './src/firebase_adapters.mjs';
import { createFirebasePrivacyCallables } from './src/firebase_callables.mjs';
import { PRIVACY_FUNCTION_OPTIONS } from './src/function_options.mjs';

/// A persistência Firestore paginada será conectada somente no PRIV-1E-B,
/// depois da auditoria externa. Até lá, a composição exportada falha fechada:
/// nenhum dado é criado ou excluído por este checkpoint local.
function unavailableProcessor() {
  const unavailable = async () => { throw new HttpsError('failed-precondition', 'Operação de privacidade ainda não está disponível.'); };
  return Object.freeze({ request: unavailable, advance: unavailable, status: unavailable });
}

if (getApps().length === 0) initializeApp();
const firestore = getFirestore();
const adapters = createFirebasePrivacyAdapters({ firestore, auth: getAuth() });
const callables = createFirebasePrivacyCallables({
  onCall,
  HttpsError,
  processor: unavailableProcessor(),
  profileReader: adapters.profileReader,
  clock: adapters.clock,
  options: PRIVACY_FUNCTION_OPTIONS,
  logger: console,
  receiptIdGenerator: new DeterministicReceiptIdGenerator(),
});

export const preparePrivacyOperation = callables.preparePrivacyOperation;
export const confirmPrivacyOperation = callables.confirmPrivacyOperation;
export const getPrivacyOperationStatus = callables.getPrivacyOperationStatus;
