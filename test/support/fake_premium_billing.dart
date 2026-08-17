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
  List<PremiumStoreProduct> products = <PremiumStoreProduct>[
    PremiumStoreProduct(
      plan: PremiumPlan.monthly,
      subscriptionId: PremiumProductCatalogConfiguration.approvedSubscriptionId,
      basePlanId: PremiumProductCatalogConfiguration.approvedMonthlyBasePlanId,
      offerId: PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId,
      offerToken: 'synthetic-monthly-trial-offer-token',
      title: 'Premium mensal',
      description: 'Teste',
      localizedPrice: 'R\$ 9,90',
      currencyCode: 'BRL',
    ),
    PremiumStoreProduct(
      plan: PremiumPlan.annual,
      subscriptionId: PremiumProductCatalogConfiguration.approvedSubscriptionId,
      basePlanId: PremiumProductCatalogConfiguration.approvedAnnualBasePlanId,
      offerToken: 'synthetic-annual-base-plan-token',
      title: 'Premium anual',
      description: 'Teste',
      localizedPrice: 'R\$ 99,90',
      currencyCode: 'BRL',
    ),
  ];

  @override
  Stream<List<PremiumPurchaseUpdate>> get purchaseUpdates => _updates.stream;

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
  PremiumPurchaseVerificationRequest? lastRequest;
  String? receivedPayload;

  @override
  bool get isAvailable => available;

  @override
  Future<PremiumPurchaseVerificationResult> verify({
    required PremiumPurchaseVerificationRequest request,
  }) async {
    calls += 1;
    lastRequest = request;
    receivedPayload = request.verificationPayload;
    return result;
  }
}

final class FakePremiumSubscriptionManagement
    implements PremiumSubscriptionManagement {
  bool result = true;
  String? subscriptionId;

  @override
  Future<bool> open({String? subscriptionId}) async {
    this.subscriptionId = subscriptionId;
    return result;
  }
}
