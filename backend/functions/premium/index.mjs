import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { createFirebasePremiumCallables } from './src/firebase_callables.mjs';
import { createFirestoreClosedTestActivation } from './src/closed_test_activation.mjs';

if (getApps().length === 0) initializeApp();

const firestore = getFirestore();
const premiumEnvironment = defineString('PREMIUM_ENVIRONMENT');
const callables = createFirebasePremiumCallables({
  onCall,
  HttpsError,
  firestore,
  closedTestActivation: createFirestoreClosedTestActivation({
    firestore,
    timestampFromDate: Timestamp.fromDate,
    environment: () => premiumEnvironment.value(),
  }),
});

export const getConfirmedEntitlement = callables.getConfirmedEntitlement;
export const verifyGooglePlayPurchase = callables.verifyGooglePlayPurchase;
export const restoreGooglePlayPurchase = callables.restoreGooglePlayPurchase;
export const activateClosedTestPremium = callables.activateClosedTestPremium;
