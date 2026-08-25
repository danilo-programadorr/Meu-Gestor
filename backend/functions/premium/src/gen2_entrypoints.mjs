import { deny } from '../.generated/subscriptions/src/errors.mjs';

/// Composição compatível com Functions Gen 2. `onCall` e `onRequest` serão
/// importados de firebase-functions/v2 somente em um incremento autorizado;
/// testes injetam factories equivalentes e não inicializam nenhum serviço.
export function createPremiumGen2Entrypoints({
  onCall,
  onRequest,
  runtime,
  verifyRtdnRequest,
  verifyAdministrativeRequest,
}) {
  if (
    typeof onCall !== 'function' ||
    typeof onRequest !== 'function' ||
    typeof verifyRtdnRequest !== 'function' ||
    typeof verifyAdministrativeRequest !== 'function' ||
    !runtime
  ) {
    throw deny('invalid_gen2_functions_factory');
  }
  const callableOptions = Object.freeze({
    enforceAppCheck: true,
    timeoutSeconds: 30,
    concurrency: 20,
    maxInstances: 2,
  });
  const requestOptions = Object.freeze({
    timeoutSeconds: 30,
    concurrency: 10,
    maxInstances: 2,
  });
  return Object.freeze({
    verifyGooglePlayPurchase: onCall(callableOptions, runtime.verifyGooglePlayPurchase),
    restoreGooglePlayPurchase: onCall(callableOptions, runtime.restoreGooglePlayPurchase),
    getConfirmedEntitlement: onCall(callableOptions, runtime.getConfirmedEntitlement),
    activateClosedTestPremium: onCall(callableOptions, runtime.activateClosedTestPremium),
    receiveGooglePlayRtdn: onRequest(requestOptions, async (request) => {
      const notification = await verifyRtdnRequest(request);
      return runtime.processRtdnSignal({ notification, rtdnVerified: true });
    }),
    administerClosedTestGrant: onRequest(requestOptions, async (request) => {
      const administrativeRequest = await verifyAdministrativeRequest(request);
      return runtime.issueClosedTestGrant(administrativeRequest);
    }),
    expireClosedTestWindow: onRequest(requestOptions, async (request) => {
      const administrativeRequest = await verifyAdministrativeRequest(request);
      return runtime.expireClosedTestWindow(administrativeRequest);
    }),
  });
}
