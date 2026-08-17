import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { createFirebasePremiumCallables } from './src/firebase_callables.mjs';

if (getApps().length === 0) initializeApp();

const callables = createFirebasePremiumCallables({
  onCall,
  HttpsError,
  firestore: getFirestore(),
});

export const getConfirmedEntitlement = callables.getConfirmedEntitlement;
export const verifyGooglePlayPurchase = callables.verifyGooglePlayPurchase;
export const restoreGooglePlayPurchase = callables.restoreGooglePlayPurchase;
