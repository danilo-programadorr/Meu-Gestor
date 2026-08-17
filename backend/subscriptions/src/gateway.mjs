import { deny, requireExactObject, requireText } from './errors.mjs';

/// Contrato para o adaptador que futuramente chamará a Google Play Developer
/// API. Não há chamada HTTP, credencial nem integração externa nesta etapa.
export class GooglePlayDeveloperApiSubscriptionGateway {
  async querySubscription(_request) {
    throw new Error('GooglePlayDeveloperApiSubscriptionGateway.querySubscription must be implemented');
  }

  async acknowledge(_request) {
    throw new Error('GooglePlayDeveloperApiSubscriptionGateway.acknowledge must be implemented');
  }
}

/// Alias de compatibilidade para o contrato local anterior.
export class GooglePlaySubscriptionGateway extends GooglePlayDeveloperApiSubscriptionGateway {}

export class DeterministicFakeGooglePlayDeveloperApiGateway extends GooglePlayDeveloperApiSubscriptionGateway {
  #responses = new Map();
  available = true;
  acknowledgementFailuresRemaining = 0;
  acknowledgements = [];
  acknowledgementAttempts = 0;
  queries = [];

  add(token, response) {
    this.#responses.set(requireText(token, 'invalid_fake_token'), structuredClone(response));
  }

  async querySubscription(request) {
    requireExactObject(request, ['packageName', 'purchaseToken'], 'invalid_google_play_query');
    const packageName = requireText(request.packageName, 'invalid_google_play_query_package');
    const purchaseToken = requireText(request.purchaseToken, 'invalid_google_play_query_token', 4096);
    if (!this.available) throw deny('google_play_service_unavailable');
    const response = this.#responses.get(purchaseToken);
    if (!response) throw deny('google_play_purchase_not_found');
    // Mantém a observabilidade do fake sem reter o token transitório.
    this.queries.push(Object.freeze({ packageName }));
    return structuredClone(response);
  }

  async acknowledge(request) {
    requireExactObject(request, ['packageName', 'subscriptionId', 'purchaseToken'], 'invalid_google_play_acknowledgement');
    const packageName = requireText(request.packageName, 'invalid_google_play_acknowledgement_package');
    const subscriptionId = requireText(request.subscriptionId, 'invalid_google_play_acknowledgement_subscription');
    const purchaseToken = requireText(request.purchaseToken, 'invalid_google_play_acknowledgement_token', 4096);
    if (!this.available) throw deny('google_play_service_unavailable');
    this.acknowledgementAttempts += 1;
    if (this.acknowledgementFailuresRemaining > 0) {
      this.acknowledgementFailuresRemaining -= 1;
      throw deny('google_play_service_unavailable');
    }
    if (!this.#responses.has(purchaseToken)) throw deny('google_play_purchase_not_found');
    const response = this.#responses.get(purchaseToken);
    if (response.packageName !== packageName || response.subscriptionId !== subscriptionId) {
      throw deny('google_play_acknowledgement_identity_mismatch');
    }
    this.acknowledgements.push(Object.freeze({ packageName, subscriptionId }));
    return Object.freeze({ acknowledged: true });
  }
}

/// Nome preservado enquanto os consumidores locais migram para o contrato
/// explícito da Play Developer API. Não representa uma integração ativa.
export class DeterministicFakeGooglePlayGateway extends DeterministicFakeGooglePlayDeveloperApiGateway {}
