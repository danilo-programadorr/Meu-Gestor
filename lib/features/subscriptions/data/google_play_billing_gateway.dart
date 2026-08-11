import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_product_mapper.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

/// Adaptador fino: resposta da Play nunca é um entitlement.
final class GooglePlayBillingGateway implements PremiumBillingGateway {
  GooglePlayBillingGateway({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchases,
      onError: (_) => _updates.add(const <PremiumPurchaseUpdate>[]),
    );
  }

  final InAppPurchase _inAppPurchase;
  final StreamController<List<PremiumPurchaseUpdate>> _updates =
      StreamController<List<PremiumPurchaseUpdate>>.broadcast();
  final Map<String, ProductDetails> _details = <String, ProductDetails>{};
  // Mantém o detalhe nativo somente enquanto a atualização correspondente está
  // em trânsito. Nunca usa token como chave nem associa duas compras pelo ID
  // compartilhado do produto.
  final Map<PremiumPurchaseUpdate, PurchaseDetails> _pendingPurchases =
      <PremiumPurchaseUpdate, PurchaseDetails>{};
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  @override
  Stream<List<PremiumPurchaseUpdate>> get purchaseUpdates => _updates.stream;

  @override
  Future<bool> isStoreAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<List<PremiumStoreProduct>> loadProducts({
    required PremiumProductCatalogConfiguration configuration,
  }) async {
    if (!configuration.hasConfiguredProducts) {
      return const <PremiumStoreProduct>[];
    }
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(<String>{
          configuration.monthlyProductId,
          configuration.annualProductId,
        });
    if (response.error != null || response.notFoundIDs.isNotEmpty) {
      return const <PremiumStoreProduct>[];
    }
    final Map<String, PremiumPlan> plans = <String, PremiumPlan>{
      configuration.monthlyProductId: PremiumPlan.monthly,
      configuration.annualProductId: PremiumPlan.annual,
    };
    _details
      ..clear()
      ..addEntries(
        response.productDetails.map(
          (ProductDetails value) =>
              MapEntry<String, ProductDetails>(value.id, value),
        ),
      );
    try {
      final List<PremiumStoreProduct> products = response.productDetails
          .map(
            (ProductDetails value) => PremiumProductMapper.map(
              details: value,
              plan: plans[value.id]!,
            ),
          )
          .toList(growable: false);
      if (products.length != 2 ||
          products
                  .map((PremiumStoreProduct item) => item.plan)
                  .toSet()
                  .length !=
              2) {
        return const <PremiumStoreProduct>[];
      }
      return products;
    } on FormatException {
      return const <PremiumStoreProduct>[];
    }
  }

  @override
  Future<bool> startSubscription({
    required PremiumStoreProduct product,
    required String obfuscatedAccountId,
  }) {
    final ProductDetails? details = _details[product.productId];
    if (details == null) return Future<bool>.value(false);
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: obfuscatedAccountId,
      ),
    );
  }

  @override
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  @override
  Future<void> completePurchase(PremiumPurchaseUpdate update) async {
    final PurchaseDetails? native = _pendingPurchases[update];
    if (native != null && native.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(native);
      _pendingPurchases.remove(update);
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    final List<PremiumPurchaseUpdate> updates = <PremiumPurchaseUpdate>[];
    for (final PurchaseDetails item in purchases) {
      final PremiumPurchaseUpdate update = PremiumPurchaseUpdate(
        productId: item.productID,
        status: switch (item.status) {
          PurchaseStatus.pending => PremiumPurchaseUpdateStatus.pending,
          PurchaseStatus.purchased => PremiumPurchaseUpdateStatus.purchased,
          PurchaseStatus.restored => PremiumPurchaseUpdateStatus.restored,
          PurchaseStatus.canceled => PremiumPurchaseUpdateStatus.cancelled,
          PurchaseStatus.error => PremiumPurchaseUpdateStatus.error,
        },
        verificationPayload: item.verificationData.serverVerificationData,
        pendingCompletePurchase: item.pendingCompletePurchase,
      );
      if (item.pendingCompletePurchase) {
        _pendingPurchases[update] = item;
      }
      updates.add(update);
    }
    _updates.add(updates);
  }

  Future<void> dispose() async {
    await _purchaseSubscription.cancel();
    await _updates.close();
  }
}
