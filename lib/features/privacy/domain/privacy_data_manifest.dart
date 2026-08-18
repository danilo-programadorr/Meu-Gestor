/// Conjunto canônico de alvos que uma operação de privacidade poderá tratar.
///
/// Os valores são contratos de backend. Eles não autorizam uma escrita pelo
/// aplicativo e não representam uma consulta Firestore executável no cliente.
enum PrivacyDataTarget {
  userProfile('users/{uid}', isFinancial: false),
  accounts('users/{uid}/accounts', isFinancial: true),
  categories('users/{uid}/categories', isFinancial: true),
  transactions('users/{uid}/transactions', isFinancial: true),
  payables('users/{uid}/payables', isFinancial: true),
  receivables('users/{uid}/receivables', isFinancial: true),
  investmentPortfolios('users/{uid}/investmentPortfolios', isFinancial: true),
  investmentAssets('users/{uid}/investmentAssets', isFinancial: true),
  investmentOperations('users/{uid}/investmentOperations', isFinancial: true),
  investmentIncomeEvents(
    'users/{uid}/investmentIncomeEvents',
    isFinancial: true,
  ),
  premiumEntitlement('users/{uid}/entitlements/premium', isFinancial: false),
  systemAdmin('system_admins/{uid}', isFinancial: false),
  premiumBillingEvents('_premiumBillingEvents', isFinancial: false),
  premiumPurchaseBindings('_premiumPurchaseBindings', isFinancial: false),
  premiumRtdnInbox('_premiumRtdnInbox', isFinancial: false),
  premiumAcknowledgementOutbox(
    '_premiumAcknowledgementOutbox',
    isFinancial: false,
  ),
  premiumAdministrativeGrants(
    '_premiumAdministrativeGrants',
    isFinancial: false,
  ),
  premiumClosedTestTesters('_premiumClosedTestTesters', isFinancial: false),
  premiumClosedTestGrants('_premiumClosedTestGrants', isFinancial: false);

  const PrivacyDataTarget(this.pathTemplate, {required this.isFinancial});

  final String pathTemplate;
  final bool isFinancial;
}

/// Manifesto fechado usado pelo futuro backend para impedir que um reset ou
/// uma exclusão se amplie por inferência para caminhos desconhecidos.
final class PrivacyDataManifest {
  const PrivacyDataManifest._();

  static const List<PrivacyDataTarget> financialResetTargets =
      <PrivacyDataTarget>[
        PrivacyDataTarget.accounts,
        PrivacyDataTarget.categories,
        PrivacyDataTarget.transactions,
        PrivacyDataTarget.payables,
        PrivacyDataTarget.receivables,
        PrivacyDataTarget.investmentPortfolios,
        PrivacyDataTarget.investmentAssets,
        PrivacyDataTarget.investmentOperations,
        PrivacyDataTarget.investmentIncomeEvents,
      ];

  static const List<PrivacyDataTarget> accountDeletionTargets =
      <PrivacyDataTarget>[
        PrivacyDataTarget.userProfile,
        ...financialResetTargets,
        PrivacyDataTarget.premiumEntitlement,
        PrivacyDataTarget.systemAdmin,
        PrivacyDataTarget.premiumBillingEvents,
        PrivacyDataTarget.premiumPurchaseBindings,
        PrivacyDataTarget.premiumRtdnInbox,
        PrivacyDataTarget.premiumAcknowledgementOutbox,
        PrivacyDataTarget.premiumAdministrativeGrants,
        PrivacyDataTarget.premiumClosedTestTesters,
        PrivacyDataTarget.premiumClosedTestGrants,
      ];
}
