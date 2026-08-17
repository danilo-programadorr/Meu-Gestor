import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';

abstract interface class PremiumBillingGateway {
  Future<bool> isStoreAvailable();

  Future<List<PremiumStoreProduct>> loadProducts({
    required PremiumProductCatalogConfiguration configuration,
  });

  Stream<List<PremiumPurchaseUpdate>> get purchaseUpdates;

  Future<bool> startSubscription({
    required PremiumStoreProduct product,
    required String obfuscatedAccountId,
  });

  Future<void> restorePurchases();
}
