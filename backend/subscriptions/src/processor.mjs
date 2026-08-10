import { deny, requireExactObject, requireText } from './errors.mjs';
import { mapGooglePlaySubscription } from './mapper.mjs';

const REQUEST_FIELDS = Object.freeze(['actor', 'environment', 'productId', 'purchaseToken']);
const ACTOR_FIELDS = Object.freeze(['uid', 'authenticated', 'appCheckVerified']);

export class SubscriptionProcessor {
  constructor({ gateway, storage, fingerprinter, tokenVault, packageName, allowedProducts, accountObfuscator, clock }) {
    Object.assign(this, { gateway, storage, fingerprinter, tokenVault, packageName, allowedProducts: new Set(allowedProducts), accountObfuscator, clock });
  }

  async process(request) {
    requireExactObject(request, REQUEST_FIELDS, 'invalid_subscription_request');
    requireExactObject(request.actor, ACTOR_FIELDS, 'invalid_subscription_actor');
    const { actor } = request;
    if (actor.authenticated !== true || actor.appCheckVerified !== true) throw deny('untrusted_subscription_actor');
    requireText(actor.uid, 'invalid_actor_uid');
    const obfuscatedAccountId = requireText(this.accountObfuscator(actor.uid), 'invalid_obfuscated_account_id');
    if (!['development', 'production'].includes(request.environment)) throw deny('invalid_environment');
    requireText(request.productId, 'invalid_product');
    requireText(request.purchaseToken, 'invalid_purchase_token', 4096);
    const fingerprint = this.fingerprinter.fingerprint(request.purchaseToken);
    const raw = await this.gateway.querySubscription({
      packageName: this.packageName, productId: request.productId, purchaseToken: request.purchaseToken,
    });
    const canonical = mapGooglePlaySubscription(raw, {
      packageName: this.packageName, productId: request.productId, environment: request.environment,
      obfuscatedAccountId, allowedProducts: this.allowedProducts,
    });
    const trustedNow = this.clock();
    if (!(trustedNow instanceof Date) || Number.isNaN(trustedNow.valueOf()) || new Date(canonical.eventTime) > trustedNow) {
      throw deny('subscription_verification_from_future');
    }
    const linkedFingerprint = canonical.linkedPurchaseToken === null ? null : this.fingerprinter.fingerprint(canonical.linkedPurchaseToken);
    const tokenReference = await this.tokenVault.store(fingerprint, request.purchaseToken);
    try {
      return await this.storage.transaction((state) => this.#persist(state, {
        actor, canonical, fingerprint, linkedFingerprint, tokenReference, trustedNow,
      }));
    } catch (error) {
      const existing = await this.storage.event(canonical.eventId);
      if (existing?.fingerprint === fingerprint && existing.ownerId === actor.uid) return existing.confirmation;
      throw error;
    }
  }

  #persist(state, context) {
    const { actor, canonical, fingerprint, linkedFingerprint, tokenReference, trustedNow } = context;
    const duplicate = state.events.get(canonical.eventId);
    if (duplicate) {
      if (duplicate.fingerprint !== fingerprint || duplicate.ownerId !== actor.uid) throw deny('event_identity_conflict');
      return duplicate.confirmation;
    }
    for (const candidate of [fingerprint, linkedFingerprint].filter(Boolean)) {
      const binding = state.bindings.get(candidate);
      if (binding && (binding.ownerId !== actor.uid || binding.environment !== canonical.environment || binding.packageName !== this.packageName)) {
        throw deny('purchase_binding_conflict');
      }
    }
    const current = state.entitlements.get(actor.uid);
    if (current && canonical.eventTime < current.lastVerifiedAt) {
      const confirmation = this.#confirmation(current, true);
      state.events.set(canonical.eventId, { ownerId: actor.uid, fingerprint, eventTime: canonical.eventTime, applied: false, confirmation });
      return confirmation;
    }
    const now = trustedNow.toISOString();
    const projection = Object.freeze({
      ownerId: actor.uid, planId: canonical.planId, status: canonical.status,
      source: canonical.source, environment: canonical.environment,
      capabilities: canonical.capabilities, startedAt: canonical.startedAt,
      currentPeriodStart: canonical.currentPeriodStart, currentPeriodEnd: canonical.currentPeriodEnd,
      graceUntil: canonical.graceUntil, cancelAtPeriodEnd: canonical.cancelAtPeriodEnd,
      cancelledAt: canonical.cancelledAt, expiredAt: canonical.expiredAt,
      revokedAt: canonical.revokedAt, refundedAt: canonical.refundedAt,
      lastVerifiedAt: canonical.eventTime, revision: (current?.revision ?? 0) + 1,
      schemaVersion: 1, createdAt: current?.createdAt ?? now, updatedAt: now,
    });
    const binding = { ownerId: actor.uid, environment: canonical.environment, packageName: this.packageName, productId: canonical.productId, tokenReference };
    state.bindings.set(fingerprint, binding);
    if (linkedFingerprint && !state.bindings.has(linkedFingerprint)) state.bindings.set(linkedFingerprint, binding);
    state.entitlements.set(actor.uid, projection);
    if (!canonical.acknowledged) state.acknowledgementOutbox.set(fingerprint, { ...binding, state: 'pending', attempts: 0 });
    const confirmation = this.#confirmation(projection, false);
    state.events.set(canonical.eventId, { ownerId: actor.uid, fingerprint, eventTime: canonical.eventTime, applied: true, confirmation });
    return confirmation;
  }

  #confirmation(projection, ignoredAsOlder) {
    return Object.freeze({ ownerId: projection.ownerId, status: projection.status, revision: projection.revision, ignoredAsOlder, requiresServerRefresh: true });
  }
}

export async function processAcknowledgementOutbox({ storage, gateway, tokenVault }) {
  return storage.transaction(async (state) => {
    let completed = 0;
    for (const [fingerprint, item] of state.acknowledgementOutbox) {
      if (item.state === 'acknowledged') continue;
      const purchaseToken = await tokenVault.retrieve(item.tokenReference);
      await gateway.acknowledge({ packageName: item.packageName, productId: item.productId, purchaseToken });
      state.acknowledgementOutbox.set(fingerprint, { ...item, state: 'acknowledged', attempts: item.attempts + 1 });
      completed += 1;
    }
    return { completed };
  });
}
