import { deny, requireExactObject, requireText } from '../../../subscriptions/src/errors.mjs';
import { issueClosedTestGrant, expireClosedTestGrants } from '../../../subscriptions/src/closed_test_grants.mjs';
import { processRtdn } from '../../../subscriptions/src/rtdn.mjs';

const PURCHASE_FIELDS = Object.freeze(['purchaseToken']);
const EMPTY_FIELDS = Object.freeze([]);
const CLOSED_TEST_FIELDS = Object.freeze(['grantId', 'ownerId', 'track']);

/// Borda local para Callables/HTTP Gen 2. Ela não conhece SDK Firebase,
/// Firebase Admin, headers reais, segredo ou rede. A futura composição Gen 2
/// injeta a identidade já validada pela plataforma e reutiliza este runtime.
export function createPremiumFunctionsRuntime({
  processor,
  storage,
  fingerprinter,
  closedTestWindow,
  authorizedClosedTestOwnerIds,
  clock,
  assertAdministrativeIdentity,
}) {
  for (const value of [processor, storage, fingerprinter, clock, assertAdministrativeIdentity]) {
    if (value === null || value === undefined) throw deny('invalid_premium_functions_dependency');
  }
  if (typeof assertAdministrativeIdentity !== 'function') {
    throw deny('invalid_premium_administrative_identity_checker');
  }

  return Object.freeze({
    verifyGooglePlayPurchase: (call) => verifyPurchase({ call, processor }),
    restoreGooglePlayPurchase: (call) => verifyPurchase({ call, processor }),
    getConfirmedEntitlement: (call) => getEntitlement({ call, storage }),
    processRtdnSignal: (request) => handleRtdn({ request, processor, storage, fingerprinter }),
    issueClosedTestGrant: (request) => issueGrant({
      request,
      closedTestWindow,
      authorizedClosedTestOwnerIds,
      storage,
      clock,
      assertAdministrativeIdentity,
    }),
    expireClosedTestWindow: (request) => expireGrantWindow({
      request,
      closedTestWindow,
      storage,
      clock,
      assertAdministrativeIdentity,
    }),
  });
}

async function verifyPurchase({ call, processor }) {
  const actor = requireTrustedCallable(call, PURCHASE_FIELDS, 'invalid_premium_purchase_callable');
  return processor.process({ actor, purchaseToken: call.data.purchaseToken });
}

async function getEntitlement({ call, storage }) {
  const actor = requireTrustedCallable(call, EMPTY_FIELDS, 'invalid_premium_entitlement_callable');
  const projection = await storage.entitlement(actor.uid);
  return projection === null
    ? Object.freeze({ entitlement: null, requiresServerRefresh: false })
    : Object.freeze({ entitlement: publicEntitlement(projection), requiresServerRefresh: false });
}

async function handleRtdn({ request, processor, storage, fingerprinter }) {
  requireExactObject(request, ['notification', 'rtdnVerified'], 'invalid_rtdn_request');
  if (request.rtdnVerified !== true) throw deny('untrusted_rtdn_signal');
  return processRtdn({ notification: request.notification, processor, storage, fingerprinter });
}

async function issueGrant({
  request,
  closedTestWindow,
  authorizedClosedTestOwnerIds,
  storage,
  clock,
  assertAdministrativeIdentity,
}) {
  requireExactObject(request, ['administrativeIdentity', 'data'], 'invalid_closed_test_administrative_request');
  await assertAdministrativeIdentity(request.administrativeIdentity);
  requireExactObject(request.data, CLOSED_TEST_FIELDS, 'invalid_closed_test_grant_request');
  return issueClosedTestGrant({
    request: request.data,
    window: closedTestWindow,
    authorizedOwnerIds: authorizedClosedTestOwnerIds,
    storage,
    clock,
  });
}

async function expireGrantWindow({ request, closedTestWindow, storage, clock, assertAdministrativeIdentity }) {
  requireExactObject(request, ['administrativeIdentity'], 'invalid_closed_test_expiration_request');
  await assertAdministrativeIdentity(request.administrativeIdentity);
  return expireClosedTestGrants({ window: closedTestWindow, storage, clock });
}

function requireTrustedCallable(call, fields, code) {
  requireExactObject(call, ['appCheckVerified', 'auth', 'data'], code);
  if (call.appCheckVerified !== true) throw deny('untrusted_premium_callable');
  requireExactObject(call.auth, ['uid'], 'invalid_premium_callable_auth');
  const uid = requireText(call.auth.uid, 'invalid_premium_callable_uid');
  requireExactObject(call.data, fields, code);
  return Object.freeze({ uid, authenticated: true, appCheckVerified: true });
}

function publicEntitlement(projection) {
  const fields = [
    'ownerId', 'planId', 'status', 'source', 'environment', 'capabilities',
    'startedAt', 'currentPeriodStart', 'currentPeriodEnd', 'graceUntil',
    'cancelAtPeriodEnd', 'cancelledAt', 'expiredAt', 'revokedAt', 'refundedAt',
    'lastVerifiedAt', 'revision', 'schemaVersion', 'createdAt', 'updatedAt',
  ];
  const result = Object.fromEntries(fields.map((field) => [field, projection[field]]));
  return Object.freeze(structuredClone(result));
}
