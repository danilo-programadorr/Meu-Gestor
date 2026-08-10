import { deny, requireExactObject, requireText } from './errors.mjs';

const FIELDS = Object.freeze(['messageId', 'projectId', 'packageName', 'environment', 'purchaseToken']);

export async function processRtdn({ notification, expected, storage, fingerprinter, processor }) {
  requireExactObject(notification, FIELDS, 'invalid_rtdn_shape');
  for (const field of FIELDS) requireText(notification[field], `invalid_rtdn_${field}`, field === 'purchaseToken' ? 4096 : 256);
  if (notification.projectId !== expected.projectId || notification.packageName !== expected.packageName || notification.environment !== expected.environment) throw deny('rtdn_environment_mismatch');
  const duplicate = (await storage.snapshot()).rtdnInbox.get(notification.messageId);
  if (duplicate) return duplicate.confirmation;
  const fingerprint = fingerprinter.fingerprint(notification.purchaseToken);
  const binding = await storage.binding(fingerprint);
  if (!binding) throw deny('rtdn_purchase_not_bound');
  const confirmation = await processor.process({
    actor: { uid: binding.ownerId, authenticated: true, appCheckVerified: true },
    environment: notification.environment, productId: binding.productId, purchaseToken: notification.purchaseToken,
  });
  await storage.transaction((state) => {
    const previous = state.rtdnInbox.get(notification.messageId);
    if (!previous) state.rtdnInbox.set(notification.messageId, { fingerprint, confirmation });
  });
  return confirmation;
}
