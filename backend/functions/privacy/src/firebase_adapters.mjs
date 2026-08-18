import {
  FirebaseAuthDeletionGateway,
  ServerClock,
  SessionRevocationGateway,
} from '../../../privacy/src/gateways.mjs';

/// Adaptadores Admin por injeção. Não inicializam app, não carregam chave e
/// permitem que a composição futura use ADC da identidade runtime dedicada.
export function createFirebasePrivacyAdapters({ firestore, auth, now = () => new Date() }) {
  if (!firestore || !auth || typeof now !== 'function') {
    throw new TypeError('Invalid Firebase Privacy adapter dependencies.');
  }
  return Object.freeze({
    profileReader: async (uid) => {
      const snapshot = await firestore.doc(`users/${uid}`).get();
      return snapshot.exists ? snapshot.data() : null;
    },
    sessionGateway: new FirebaseSessionRevocationAdapter(auth),
    authGateway: new FirebaseAuthDeletionAdapter(auth),
    clock: new FirebaseServerClock(now),
  });
}

export class FirebaseSessionRevocationAdapter extends SessionRevocationGateway {
  constructor(auth) { super(); this.auth = auth; }
  async revokeRefreshTokens(uid) { await this.auth.revokeRefreshTokens(uid); }
}

export class FirebaseAuthDeletionAdapter extends FirebaseAuthDeletionGateway {
  constructor(auth) { super(); this.auth = auth; }
  async deleteUser(uid) { await this.auth.deleteUser(uid); }
}

export class FirebaseServerClock extends ServerClock {
  constructor(now) { super(); this.nowFactory = now; }
  now() { return this.nowFactory(); }
}
