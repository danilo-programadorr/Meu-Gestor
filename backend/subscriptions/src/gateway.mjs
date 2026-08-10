import { deny, requireText } from './errors.mjs';

export class GooglePlaySubscriptionGateway {
  async querySubscription(_request) {
    throw new Error('GooglePlaySubscriptionGateway.querySubscription must be implemented');
  }

  async acknowledge(_request) {
    throw new Error('GooglePlaySubscriptionGateway.acknowledge must be implemented');
  }
}

export class DeterministicFakeGooglePlayGateway extends GooglePlaySubscriptionGateway {
  #responses = new Map();
  acknowledgements = [];

  add(token, response) {
    this.#responses.set(requireText(token, 'invalid_fake_token'), structuredClone(response));
  }

  async querySubscription({ purchaseToken }) {
    const response = this.#responses.get(purchaseToken);
    if (!response) throw deny('google_play_purchase_not_found');
    return structuredClone(response);
  }

  async acknowledge({ packageName, productId, purchaseToken }) {
    if (!this.#responses.has(purchaseToken)) throw deny('google_play_purchase_not_found');
    this.acknowledgements.push({ packageName, productId });
    return Object.freeze({ acknowledged: true });
  }
}
