import { deny, requireExactObject, requireText } from './errors.mjs';

const FIELDS = Object.freeze(['messageId', 'projectId', 'packageName', 'purchaseToken']);

export async function processRtdn({ notification, storage, fingerprinter, processor }) {
  requireExactObject(notification, FIELDS, 'invalid_rtdn_shape');
  for (const field of FIELDS) requireText(notification[field], `invalid_rtdn_${field}`, field === 'purchaseToken' ? 4096 : 256);
  // RTDN é apenas um sinal: não traz plano, oferta ou ambiente confiável. A
  // reconsulta usa o vínculo ambiente/projeto configurado localmente.
  if (notification.projectId !== processor.projectId || notification.packageName !== processor.packageName) {
    throw deny('rtdn_environment_mismatch');
  }
  const duplicate = (await storage.snapshot()).rtdnInbox.get(notification.messageId);
  if (duplicate) return duplicate.confirmation;
  const fingerprint = fingerprinter.fingerprint(notification.purchaseToken);
  const binding = await storage.binding(fingerprint);
  if (!binding) throw deny('rtdn_purchase_not_bound');
  if (
    binding.environment !== processor.environment ||
    binding.projectId !== processor.projectId ||
    binding.packageName !== processor.packageName
  ) {
    throw deny('rtdn_binding_environment_mismatch');
  }
  const confirmation = await processor.process({
    actor: { uid: binding.ownerId, authenticated: true, appCheckVerified: true },
    purchaseToken: notification.purchaseToken,
  });
  await storage.transaction((state) => {
    const previous = state.rtdnInbox.get(notification.messageId);
    if (!previous) state.rtdnInbox.set(notification.messageId, { fingerprint, confirmation });
  });
  return confirmation;
}
