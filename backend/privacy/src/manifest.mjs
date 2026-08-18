const financialTargets = Object.freeze([
  'accounts', 'categories', 'transactions', 'payables', 'receivables',
  'investmentPortfolios', 'investmentAssets', 'investmentOperations',
  'investmentIncomeEvents',
]);

const accountOnlyTargets = Object.freeze([
  'userProfile', 'premiumEntitlement', 'systemAdmin', 'premiumBillingEvents',
  'premiumPurchaseBindings', 'premiumRtdnInbox', 'premiumAcknowledgementOutbox',
  'premiumAdministrativeGrants', 'premiumClosedTestTesters', 'premiumClosedTestGrants',
]);

export const PRIVACY_TARGETS = Object.freeze([
  ...financialTargets,
  ...accountOnlyTargets,
]);

export const DEFAULT_PRIVACY_MANIFEST = Object.freeze({
  financialReset: financialTargets,
  accountDeletion: Object.freeze([...financialTargets, ...accountOnlyTargets]),
});

export function createPrivacyManifest({ financialReset, accountDeletion }) {
  const manifest = {
    financialReset: Object.freeze([...financialReset]),
    accountDeletion: Object.freeze([...accountDeletion]),
  };
  validatePrivacyManifest(manifest);
  return Object.freeze(manifest);
}

export function validatePrivacyManifest(manifest) {
  for (const type of ['financialReset', 'accountDeletion']) {
    const targets = manifest?.[type];
    if (!Array.isArray(targets) || targets.length === 0 || new Set(targets).size !== targets.length) {
      throw new Error('privacy_manifest_invalid');
    }
    if (targets.some((target) => !PRIVACY_TARGETS.includes(target))) {
      throw new Error('privacy_manifest_unknown_target');
    }
  }
  if (manifest.financialReset.length !== financialTargets.length ||
      !financialTargets.every((target) => manifest.financialReset.includes(target)) ||
      manifest.accountDeletion.length !== PRIVACY_TARGETS.length ||
      !PRIVACY_TARGETS.every((target) => manifest.accountDeletion.includes(target))) {
    throw new Error('privacy_manifest_incomplete');
  }
}

export const isFinancialTarget = (target) => financialTargets.includes(target);
