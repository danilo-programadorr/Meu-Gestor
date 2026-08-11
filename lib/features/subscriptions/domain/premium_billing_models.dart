import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

/// IDs de catálogo fornecidos pela configuração do ambiente, nunca pelo UI.
final class PremiumProductCatalogConfiguration {
  const PremiumProductCatalogConfiguration({
    required this.monthlyProductId,
    required this.annualProductId,
    required this.androidPackageName,
  });

  final String monthlyProductId;
  final String annualProductId;
  final String androidPackageName;

  bool get hasConfiguredProducts =>
      _isValidProductId(monthlyProductId) &&
      _isValidProductId(annualProductId) &&
      monthlyProductId != annualProductId;

  String? productIdFor(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => monthlyProductId,
    PremiumPlan.annual => annualProductId,
    PremiumPlan.free => null,
  };

  static bool _isValidProductId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9_.]{2,127}$').hasMatch(value);

  bool get hasValidAndroidPackage => RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  ).hasMatch(androidPackageName);
}

final class PremiumStoreProduct {
  PremiumStoreProduct({
    required this.plan,
    required this.productId,
    required this.title,
    required this.description,
    required this.localizedPrice,
    required this.currencyCode,
    required this.periodLabel,
    this.offerLabel,
  }) {
    if (!plan.isPremium ||
        productId.trim().isEmpty ||
        title.trim().isEmpty ||
        localizedPrice.trim().isEmpty ||
        currencyCode.trim().length != 3 ||
        periodLabel.trim().isEmpty) {
      throw ArgumentError.value(productId, 'productId', 'Produto inválido.');
    }
  }

  final PremiumPlan plan;
  final String productId;
  final String title;
  final String description;
  final String localizedPrice;
  final String currencyCode;
  final String periodLabel;
  final String? offerLabel;
}

enum PremiumPurchaseUpdateStatus {
  pending,
  purchased,
  restored,
  cancelled,
  error,
}

/// Token transitório: não deve ser persistido, registrado nem exposto em UI.
final class PremiumPurchaseUpdate {
  const PremiumPurchaseUpdate({
    required this.productId,
    required this.status,
    required this.verificationPayload,
    required this.pendingCompletePurchase,
  });

  final String productId;
  final PremiumPurchaseUpdateStatus status;
  final String verificationPayload;
  final bool pendingCompletePurchase;
}

enum PremiumPurchaseVerificationResult { confirmed, denied, unavailable }

final class PremiumBillingAvailability {
  const PremiumBillingAvailability({
    required this.storeAvailable,
    required this.productsConfigured,
    required this.backendVerificationAvailable,
    required this.identityAvailable,
    required this.appCheckPrepared,
    required this.environmentValid,
    required this.eligibleUser,
  });

  final bool storeAvailable;
  final bool productsConfigured;
  final bool backendVerificationAvailable;
  final bool identityAvailable;
  final bool appCheckPrepared;
  final bool environmentValid;
  final bool eligibleUser;

  bool get canStartPurchase =>
      storeAvailable &&
      productsConfigured &&
      backendVerificationAvailable &&
      identityAvailable &&
      appCheckPrepared &&
      environmentValid &&
      eligibleUser;

  String get safeMessage {
    if (!productsConfigured ||
        !backendVerificationAvailable ||
        !identityAvailable) {
      return 'Assinaturas em preparação. Nenhuma cobrança pode ser iniciada agora.';
    }
    if (!eligibleUser) {
      return 'Confirme sua sessão, e-mail e perfil antes de assinar.';
    }
    if (!storeAvailable) {
      return 'A Google Play está indisponível no momento.';
    }
    if (!environmentValid || !appCheckPrepared) {
      return 'A assinatura ainda não está disponível neste ambiente.';
    }
    return 'Assinatura disponível.';
  }
}
