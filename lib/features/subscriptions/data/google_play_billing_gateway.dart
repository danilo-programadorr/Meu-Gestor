import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  final Map<PremiumStoreProduct, GooglePlayProductDetails> _details =
      <PremiumStoreProduct, GooglePlayProductDetails>{};
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  @override
  Stream<List<PremiumPurchaseUpdate>> get purchaseUpdates => _updates.stream;

  @override
  Future<bool> isStoreAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<List<PremiumStoreProduct>> loadProducts({
    required PremiumProductCatalogConfiguration configuration,
  }) async {
    if (!configuration.hasConfiguredProducts ||
        !configuration.matchesApprovedCommercialModel) {
      return const <PremiumStoreProduct>[];
    }
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(<String>{configuration.subscriptionId});
    if (response.error != null || response.notFoundIDs.isNotEmpty) {
      return const <PremiumStoreProduct>[];
    }
    try {
      final Map<PremiumStoreProduct, GooglePlayProductDetails> candidates =
          <PremiumStoreProduct, GooglePlayProductDetails>{};
      for (final ProductDetails value in response.productDetails) {
        if (value is! GooglePlayProductDetails ||
            value.id != configuration.subscriptionId ||
            value.subscriptionIndex == null) {
          return const <PremiumStoreProduct>[];
        }
        final List<SubscriptionOfferDetailsWrapper>? offers =
            value.productDetails.subscriptionOfferDetails;
        final int selectionIndex = value.subscriptionIndex!;
        if (offers == null || selectionIndex >= offers.length) {
          return const <PremiumStoreProduct>[];
        }
        final SubscriptionOfferDetailsWrapper offer = offers[selectionIndex];
        final PremiumPlan? plan = _planFor(configuration, offer.basePlanId);
        if (plan == null || value.offerToken != offer.offerIdToken) {
          return const <PremiumStoreProduct>[];
        }
        final PremiumStoreProduct product = PremiumProductMapper.map(
          details: value,
          plan: plan,
          subscriptionId: configuration.subscriptionId,
          basePlanId: offer.basePlanId,
          offerId: offer.offerId,
          offerToken: offer.offerIdToken,
        );
        candidates[product] = value;
      }
      final List<PremiumStoreProduct> products = configuration
          .selectDisplayProducts(candidates.keys);
      if (products.length != 2) {
        return const <PremiumStoreProduct>[];
      }
      _details
        ..clear()
        ..addEntries(
          products.map(
            (PremiumStoreProduct product) =>
                MapEntry<PremiumStoreProduct, GooglePlayProductDetails>(
                  product,
                  candidates[product]!,
                ),
          ),
        );
      return products;
    } on FormatException {
      _details.clear();
      return const <PremiumStoreProduct>[];
    }
  }

  @override
  Future<bool> startSubscription({
    required PremiumStoreProduct product,
    required String obfuscatedAccountId,
  }) {
    final GooglePlayProductDetails? details = _details[product];
    if (details == null ||
        details.id != product.subscriptionId ||
        details.offerToken != product.offerToken ||
        product.offerToken.trim().isEmpty ||
        obfuscatedAccountId.trim().isEmpty) {
      return Future<bool>.value(false);
    }
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: details,
        applicationUserName: obfuscatedAccountId,
        offerToken: product.offerToken,
      ),
    );
  }

  @override
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  void _handlePurchases(List<PurchaseDetails> purchases) {
    final List<PremiumPurchaseUpdate> updates = <PremiumPurchaseUpdate>[];
    for (final PurchaseDetails item in purchases) {
      final PremiumPurchaseUpdate update = PremiumPurchaseUpdate(
        subscriptionId: item.productID,
        status: switch (item.status) {
          PurchaseStatus.pending => PremiumPurchaseUpdateStatus.pending,
          PurchaseStatus.purchased => PremiumPurchaseUpdateStatus.purchased,
          PurchaseStatus.restored => PremiumPurchaseUpdateStatus.restored,
          PurchaseStatus.canceled => PremiumPurchaseUpdateStatus.cancelled,
          PurchaseStatus.error => PremiumPurchaseUpdateStatus.error,
        },
        verificationPayload: item.verificationData.serverVerificationData,
      );
      updates.add(update);
    }
    _updates.add(updates);
  }

  Future<void> dispose() async {
    await _purchaseSubscription.cancel();
    await _updates.close();
  }

  PremiumPlan? _planFor(
    PremiumProductCatalogConfiguration configuration,
    String basePlanId,
  ) {
    if (basePlanId == configuration.monthlyBasePlanId) {
      return PremiumPlan.monthly;
    }
    if (basePlanId == configuration.annualBasePlanId) {
      return PremiumPlan.annual;
    }
    return null;
  }
}
