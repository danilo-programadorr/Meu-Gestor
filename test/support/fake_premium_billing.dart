import 'dart:async';

import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_identity_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_verification_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_subscription_management.dart';

final class FakePremiumBillingGateway implements PremiumBillingGateway {
  final StreamController<List<PremiumPurchaseUpdate>> _updates =
      StreamController<List<PremiumPurchaseUpdate>>.broadcast();
  bool storeAvailable = true;
  bool starts = true;
  Object? nextError;
  int startCalls = 0;
  int restoreCalls = 0;
  int completeCalls = 0;
  List<PremiumStoreProduct> products = <PremiumStoreProduct>[
    PremiumStoreProduct(
      plan: PremiumPlan.monthly,
      productId: 'premium.monthly',
      title: 'Premium mensal',
      description: 'Teste',
      localizedPrice: 'R\$ 9,90',
      currencyCode: 'BRL',
      periodLabel: 'Mensal',
    ),
    PremiumStoreProduct(
      plan: PremiumPlan.annual,
      productId: 'premium.annual',
      title: 'Premium anual',
      description: 'Teste',
      localizedPrice: 'R\$ 99,90',
      currencyCode: 'BRL',
      periodLabel: 'Anual',
    ),
  ];

  @override
  Stream<List<PremiumPurchaseUpdate>> get purchaseUpdates => _updates.stream;

  @override
  Future<void> completePurchase(PremiumPurchaseUpdate update) async {
    completeCalls += 1;
  }

  @override
  Future<bool> isStoreAvailable() async => storeAvailable;

  @override
  Future<List<PremiumStoreProduct>> loadProducts({
    required PremiumProductCatalogConfiguration configuration,
  }) async {
    if (nextError case final Object error) {
      nextError = null;
      throw error;
    }
    return products;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
    if (nextError case final Object error) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<bool> startSubscription({
    required PremiumStoreProduct product,
    required String obfuscatedAccountId,
  }) async {
    startCalls += 1;
    if (nextError case final Object error) {
      nextError = null;
      throw error;
    }
    return starts;
  }

  void emit(PremiumPurchaseUpdate update) =>
      _updates.add(<PremiumPurchaseUpdate>[update]);

  Future<void> close() => _updates.close();
}

final class FakePremiumPurchaseIdentityGateway
    implements PremiumPurchaseIdentityGateway {
  FakePremiumPurchaseIdentityGateway({
    this.available = true,
    this.identifier = 'opaque-test-identity',
  });

  bool available;
  String? identifier;

  @override
  bool get isAvailable => available;

  @override
  Future<String?> currentObfuscatedAccountId() async => identifier;
}

final class FakePremiumPurchaseVerificationGateway
    implements PremiumPurchaseVerificationGateway {
  FakePremiumPurchaseVerificationGateway({
    this.available = true,
    this.result = PremiumPurchaseVerificationResult.confirmed,
  });

  bool available;
  PremiumPurchaseVerificationResult result;
  int calls = 0;
  String? lastProductId;
  String? receivedPayload;

  @override
  bool get isAvailable => available;

  @override
  Future<PremiumPurchaseVerificationResult> verify({
    required String productId,
    required String verificationPayload,
  }) async {
    calls += 1;
    lastProductId = productId;
    receivedPayload = verificationPayload;
    return result;
  }
}

final class FakePremiumSubscriptionManagement
    implements PremiumSubscriptionManagement {
  bool result = true;
  String? productId;

  @override
  Future<bool> open({String? productId}) async {
    this.productId = productId;
    return result;
  }
}
