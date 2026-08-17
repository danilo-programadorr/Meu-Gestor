import { randomUUID } from 'node:crypto';
import { deny, requireExactObject, requireText, requireUtcInstant } from './errors.mjs';
import { mapGooglePlaySubscription } from './mapper.mjs';
import { resolvePremiumGooglePlayCatalog } from './catalog.mjs';
import { resolveSubscriptionBackendEnvironment } from './environment.mjs';
import { assertSubscriptionTransition } from './transition_policy.mjs';

const REQUEST_FIELDS = Object.freeze(['actor', 'purchaseToken']);
const ACTOR_FIELDS = Object.freeze(['uid', 'authenticated', 'appCheckVerified']);

export class SubscriptionProcessor {
  constructor({ gateway, storage, fingerprinter, tokenVault, packageName, environmentConfiguration, catalog, accountObfuscator, clock }) {
    requireText(packageName, 'invalid_subscription_package_name');
    const configuredEnvironment = resolveSubscriptionBackendEnvironment(environmentConfiguration);
    this.gateway = gateway;
    this.storage = storage;
    this.fingerprinter = fingerprinter;
    this.tokenVault = tokenVault;
    this.packageName = packageName;
    // Ambiente e catálogo são configuração local do backend, nunca campos de
    // uma solicitação de compra enviada pelo aplicativo.
    this.environment = configuredEnvironment.environment;
    this.projectId = configuredEnvironment.projectId;
    this.catalog = resolvePremiumGooglePlayCatalog(catalog);
    this.accountObfuscator = accountObfuscator;
    this.clock = clock;
  }

  async process(request) {
    requireExactObject(request, REQUEST_FIELDS, 'invalid_subscription_request');
    requireExactObject(request.actor, ACTOR_FIELDS, 'invalid_subscription_actor');
    const { actor } = request;
    if (actor.authenticated !== true || actor.appCheckVerified !== true) throw deny('untrusted_subscription_actor');
    requireText(actor.uid, 'invalid_actor_uid');
    const obfuscatedAccountId = requireText(this.accountObfuscator(actor.uid), 'invalid_obfuscated_account_id');
    requireText(request.purchaseToken, 'invalid_purchase_token', 4096);
    const fingerprint = this.fingerprinter.fingerprint(request.purchaseToken);
    const raw = await this.gateway.querySubscription({
      packageName: this.packageName, purchaseToken: request.purchaseToken,
    });
    const canonical = mapGooglePlaySubscription(raw, {
      packageName: this.packageName, environment: this.environment,
      obfuscatedAccountId, catalog: this.catalog,
    });
    const trustedNow = this.clock();
    if (!(trustedNow instanceof Date) || Number.isNaN(trustedNow.valueOf()) || new Date(canonical.eventTime) > trustedNow) {
      throw deny('subscription_verification_from_future');
    }
    const linkedFingerprint = canonical.linkedPurchaseToken === null ? null : this.fingerprinter.fingerprint(canonical.linkedPurchaseToken);
    const requiresAcknowledgement = canonical.status !== 'pending' && !canonical.acknowledged;
    const tokenReference = requiresAcknowledgement
      ? await this.tokenVault.store(fingerprint, request.purchaseToken)
      : null;
    let persisted;
    try {
      persisted = await this.storage.transaction((state) => this.#persist(state, {
        actor, canonical, fingerprint, linkedFingerprint, tokenReference, trustedNow,
      }));
    } catch (error) {
      const existing = await this.storage.event(canonical.eventId);
      if (existing?.fingerprint === fingerprint && existing.ownerId === actor.uid) {
        // Uma confirmação pode ter sido persistida por esta tentativa antes de
        // um timeout, ou por outra tentativa concorrente. A referência desta
        // invocação só sobrevive se estiver no estado persistido; caso
        // contrário, ela é órfã e deve ser descartada antes da confirmação.
        await this.#discardTokenUnlessReferenced(tokenReference);
        return existing.confirmation;
      }
      await this.#discardTokenUnlessReferenced(tokenReference);
      throw error;
    }
    if (!persisted.retainsTokenReference) {
      await this.#discardTokenUnlessReferenced(tokenReference);
    }
    return persisted.confirmation;
  }

  #persist(state, context) {
    const { actor, canonical, fingerprint, linkedFingerprint, tokenReference, trustedNow } = context;
    const duplicate = state.events.get(canonical.eventId);
    if (duplicate) {
      if (duplicate.fingerprint !== fingerprint || duplicate.ownerId !== actor.uid) throw deny('event_identity_conflict');
      return this.#persistenceResult(state, duplicate.confirmation, tokenReference);
    }
    for (const candidate of [fingerprint, linkedFingerprint].filter(Boolean)) {
      const binding = state.bindings.get(candidate);
      if (binding && (
        binding.ownerId !== actor.uid ||
        binding.environment !== canonical.environment ||
        binding.projectId !== this.projectId ||
        binding.packageName !== this.packageName
      )) {
        throw deny('purchase_binding_conflict');
      }
    }
    const current = state.entitlements.get(actor.uid);
    if (current && canonical.eventTime < current.lastVerifiedAt) {
      const confirmation = this.#confirmation(current, true);
      state.events.set(canonical.eventId, { ownerId: actor.uid, fingerprint, eventTime: canonical.eventTime, applied: false, confirmation });
      return this.#persistenceResult(state, confirmation, tokenReference);
    }
    if (current) this.#assertOriginTransition(current, canonical);
    const isNewPurchaseCycle = this.#isNewPurchaseCycle({ current, canonical, fingerprint, linkedFingerprint });
    if (current) assertSubscriptionTransition({ current, next: canonical, isNewPurchaseCycle });
    const now = trustedNow.toISOString();
    const projection = Object.freeze({
      ownerId: actor.uid, planId: canonical.planId, status: canonical.status,
      source: canonical.source, environment: canonical.environment,
      // Metadados internos do backend; não são parte do contrato público do
      // entitlement lido pelo aplicativo. Impedem a troca de origem no mesmo
      // armazenamento sem registrar Project ID ou package em logs/auditoria.
      projectId: this.projectId, packageName: this.packageName,
      purchaseCycleFingerprint: isNewPurchaseCycle || !current?.purchaseCycleFingerprint
        ? fingerprint
        : current.purchaseCycleFingerprint,
      capabilities: canonical.capabilities, startedAt: canonical.startedAt,
      currentPeriodStart: canonical.currentPeriodStart, currentPeriodEnd: canonical.currentPeriodEnd,
      graceUntil: canonical.graceUntil, cancelAtPeriodEnd: canonical.cancelAtPeriodEnd,
      cancelledAt: canonical.cancelledAt, expiredAt: canonical.expiredAt,
      revokedAt: canonical.revokedAt, refundedAt: canonical.refundedAt,
      lastVerifiedAt: canonical.eventTime, revision: (current?.revision ?? 0) + 1,
      schemaVersion: 1, createdAt: current?.createdAt ?? now, updatedAt: now,
    });
    const existingOutbox = state.acknowledgementOutbox.get(fingerprint);
    const existingOutboxTokenReference = this.#activeOutboxTokenReference(existingOutbox);
    this.#assertActiveOutboxIdentity({
      outbox: existingOutbox,
      tokenReference: existingOutboxTokenReference,
      actor,
      canonical,
    });
    if (canonical.status === 'pending' && existingOutboxTokenReference !== null) {
      throw deny('pending_subscription_acknowledgement_state');
    }
    const bindingTokenReference = canonical.status === 'pending'
      ? null
      : existingOutboxTokenReference ?? tokenReference;
    const binding = {
      ownerId: actor.uid,
      environment: canonical.environment,
      projectId: this.projectId,
      packageName: this.packageName,
      purchaseCycleFingerprint: projection.purchaseCycleFingerprint,
      subscriptionId: canonical.subscriptionId,
      basePlanId: canonical.basePlanId,
      offerId: canonical.offerId,
    };
    if (bindingTokenReference !== null) binding.tokenReference = bindingTokenReference;
    state.bindings.set(fingerprint, binding);
    if (linkedFingerprint && !state.bindings.has(linkedFingerprint)) state.bindings.set(linkedFingerprint, binding);
    state.entitlements.set(actor.uid, projection);
    if (canonical.status !== 'pending' && !canonical.acknowledged && existingOutboxTokenReference === null) {
      requireText(tokenReference, 'invalid_acknowledgement_token_reference');
      state.acknowledgementOutbox.set(fingerprint, { ...binding, state: 'pending', attempts: 0 });
    }
    const confirmation = this.#confirmation(projection, false);
    state.events.set(canonical.eventId, { ownerId: actor.uid, fingerprint, eventTime: canonical.eventTime, applied: true, confirmation });
    return this.#persistenceResult(state, confirmation, tokenReference);
  }

  #persistenceResult(state, confirmation, tokenReference) {
    return Object.freeze({
      confirmation,
      retainsTokenReference: this.#hasTokenReference(state, tokenReference),
    });
  }

  #activeOutboxTokenReference(outbox) {
    if (outbox === undefined) return null;
    if (outbox.state === 'acknowledged' && !Object.hasOwn(outbox, 'tokenReference')) return null;
    return requireText(outbox.tokenReference, 'invalid_acknowledgement_token_reference');
  }

  #assertActiveOutboxIdentity({ outbox, tokenReference, actor, canonical }) {
    if (tokenReference === null) return;
    if (
      outbox.ownerId !== actor.uid ||
      outbox.environment !== canonical.environment ||
      outbox.projectId !== this.projectId ||
      outbox.packageName !== this.packageName ||
      outbox.subscriptionId !== canonical.subscriptionId
    ) {
      throw deny('acknowledgement_outbox_binding_conflict');
    }
  }

  #isNewPurchaseCycle({ current, canonical, fingerprint, linkedFingerprint }) {
    if (!current) return true;
    if (current.source !== 'googlePlay') {
      return current.source === 'developmentGrant' && canonical.source === 'googlePlay';
    }
    if (typeof current.purchaseCycleFingerprint !== 'string') return false;
    // Após expiração ou terminalidade, a Play pode vincular o token da nova
    // compra ao ciclo anterior. O novo token ainda representa um ciclo novo;
    // manter o vínculo antigo como identidade impediria uma reassinatura
    // legítima para sempre.
    if (['expired', 'revoked', 'refunded'].includes(current.status)) {
      return current.purchaseCycleFingerprint !== fingerprint;
    }
    return current.purchaseCycleFingerprint !== fingerprint && current.purchaseCycleFingerprint !== linkedFingerprint;
  }

  #assertOriginTransition(current, canonical) {
    if (current.environment !== canonical.environment) {
      throw deny('subscription_origin_transition_denied');
    }
    if (current.source !== 'googlePlay') return;
    if (
      current.projectId !== this.projectId ||
      current.packageName !== this.packageName
    ) {
      throw deny('subscription_origin_transition_denied');
    }
  }

  async #discardTokenUnlessReferenced(tokenReference) {
    if (tokenReference === null) return;
    const state = await this.storage.snapshot();
    if (this.#hasTokenReference(state, tokenReference)) return;
    await this.tokenVault.discard(tokenReference);
  }

  #hasTokenReference(state, tokenReference) {
    if (tokenReference === null) return false;
    for (const binding of state.bindings.values()) {
      if (binding.tokenReference === tokenReference) return true;
    }
    for (const outboxItem of state.acknowledgementOutbox.values()) {
      if (outboxItem.tokenReference === tokenReference) return true;
    }
    return false;
  }

  #confirmation(projection, ignoredAsOlder) {
    return Object.freeze({ ownerId: projection.ownerId, status: projection.status, revision: projection.revision, ignoredAsOlder, requiresServerRefresh: true });
  }
}

const ACKNOWLEDGEMENT_LEASE_DURATION_MS = 5 * 60 * 1000;

/// A chamada à Play nunca ocorre dentro de uma transação de armazenamento.
/// A transação só reivindica/finaliza a saída; repetir uma confirmação após
/// perda do lease permanece seguro porque acknowledge é idempotente na loja.
export async function processAcknowledgementOutbox({
  storage,
  gateway,
  tokenVault,
  clock,
  claimIdFactory = randomUUID,
  leaseDurationMs = ACKNOWLEDGEMENT_LEASE_DURATION_MS,
}) {
  if (!Number.isInteger(leaseDurationMs) || leaseDurationMs <= 0) {
    throw deny('invalid_acknowledgement_lease_duration');
  }
  let completed = 0;
  while (true) {
    const claim = await claimNextAcknowledgement({
      storage,
      clock,
      claimIdFactory,
      leaseDurationMs,
    });
    if (claim === null) return Object.freeze({ completed });
    try {
      if (claim.kind === 'acknowledgement') {
        const purchaseToken = await tokenVault.retrieve(claim.tokenReference);
        await gateway.acknowledge({
          packageName: claim.packageName,
          subscriptionId: claim.subscriptionId,
          purchaseToken,
        });
        const acknowledged = await markAcknowledgementClaim({ storage, claim });
        if (acknowledged) completed += 1;
      } else {
        await tokenVault.discard(claim.tokenReference);
        await finalizeAcknowledgementCleanup({ storage, claim });
      }
    } catch (error) {
      try {
        await releaseAcknowledgementClaim({ storage, claim });
      } catch {
        // A expiração do lease permite nova tentativa sem reter o token.
      }
      throw error;
    }
  }
}

async function claimNextAcknowledgement({ storage, clock, claimIdFactory, leaseDurationMs }) {
  const now = trustedAcknowledgementNow(clock);
  if (typeof claimIdFactory !== 'function') throw deny('invalid_acknowledgement_claim_factory');
  const claimId = requireText(claimIdFactory(), 'invalid_acknowledgement_claim_id');
  const leaseExpiresAt = new Date(now.valueOf() + leaseDurationMs).toISOString();
  return storage.transaction((state) => {
    for (const [fingerprint, item] of state.acknowledgementOutbox) {
      if (item.state === 'acknowledged' && !Object.hasOwn(item, 'tokenReference')) continue;
      if (['claimed', 'cleanupClaimed'].includes(item.state) && hasActiveAcknowledgementLease(item, now)) continue;
      if (!['pending', 'claimed', 'acknowledged', 'cleanupClaimed'].includes(item.state) ||
          !Number.isInteger(item.attempts) || item.attempts < 0) {
        throw deny('invalid_acknowledgement_outbox_item');
      }
      requireText(fingerprint, 'invalid_acknowledgement_fingerprint');
      requireText(item.packageName, 'invalid_acknowledgement_package_name');
      requireText(item.subscriptionId, 'invalid_acknowledgement_subscription_id');
      requireText(item.tokenReference, 'invalid_acknowledgement_token_reference');
      const { claimId: _previousClaimId, leaseExpiresAt: _previousLeaseExpiresAt, ...pending } = item;
      const kind = item.state === 'acknowledged' || item.state === 'cleanupClaimed'
        ? 'cleanup'
        : 'acknowledgement';
      state.acknowledgementOutbox.set(fingerprint, {
        ...pending,
        state: kind === 'cleanup' ? 'cleanupClaimed' : 'claimed',
        attempts: kind === 'acknowledgement' ? item.attempts + 1 : item.attempts,
        claimId,
        leaseExpiresAt,
      });
      return Object.freeze({
        fingerprint,
        packageName: item.packageName,
        subscriptionId: item.subscriptionId,
        tokenReference: item.tokenReference,
        claimId,
        kind,
      });
    }
    return null;
  });
}

function trustedAcknowledgementNow(clock) {
  if (typeof clock !== 'function') throw deny('invalid_acknowledgement_clock');
  const now = clock();
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) throw deny('invalid_acknowledgement_clock');
  return now;
}

function hasActiveAcknowledgementLease(item, now) {
  requireText(item.claimId, 'invalid_acknowledgement_claim_id');
  const leaseExpiresAt = requireUtcInstant(item.leaseExpiresAt, 'invalid_acknowledgement_lease');
  return leaseExpiresAt > now;
}

async function markAcknowledgementClaim({ storage, claim }) {
  return storage.transaction((state) => {
    const item = state.acknowledgementOutbox.get(claim.fingerprint);
    if (!item || item.state !== 'claimed' || item.claimId !== claim.claimId) return false;
    const {
      claimId: _claimId,
      leaseExpiresAt: _leaseExpiresAt,
      ...pending
    } = item;
    state.acknowledgementOutbox.set(claim.fingerprint, {
      ...pending,
      state: 'acknowledged',
    });
    for (const [fingerprint, binding] of state.bindings) {
      if (binding.tokenReference !== claim.tokenReference) continue;
      const { tokenReference: _bindingTokenReference, ...sanitizedBinding } = binding;
      state.bindings.set(fingerprint, sanitizedBinding);
    }
    return true;
  });
}

async function finalizeAcknowledgementCleanup({ storage, claim }) {
  return storage.transaction((state) => {
    const item = state.acknowledgementOutbox.get(claim.fingerprint);
    if (!item || item.state !== 'cleanupClaimed' || item.claimId !== claim.claimId) return false;
    const {
      claimId: _claimId,
      leaseExpiresAt: _leaseExpiresAt,
      tokenReference: _tokenReference,
      ...acknowledged
    } = item;
    state.acknowledgementOutbox.set(claim.fingerprint, {
      ...acknowledged,
      state: 'acknowledged',
    });
    return true;
  });
}

async function releaseAcknowledgementClaim({ storage, claim }) {
  return storage.transaction((state) => {
    const item = state.acknowledgementOutbox.get(claim.fingerprint);
    const claimedState = claim.kind === 'cleanup' ? 'cleanupClaimed' : 'claimed';
    if (!item || item.state !== claimedState || item.claimId !== claim.claimId) return false;
    const { claimId: _claimId, leaseExpiresAt: _leaseExpiresAt, ...pending } = item;
    state.acknowledgementOutbox.set(claim.fingerprint, {
      ...pending,
      state: claim.kind === 'cleanup' ? 'acknowledged' : 'pending',
    });
    return true;
  });
}
