import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_subscription_management.dart';

void main() {
  const PremiumProductCatalogConfiguration
  configuration = PremiumProductCatalogConfiguration(
    subscriptionId: PremiumProductCatalogConfiguration.approvedSubscriptionId,
    monthlyBasePlanId:
        PremiumProductCatalogConfiguration.approvedMonthlyBasePlanId,
    annualBasePlanId:
        PremiumProductCatalogConfiguration.approvedAnnualBasePlanId,
    monthlyTrialOfferId:
        PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId,
    monthlyTrialDurationHours:
        PremiumProductCatalogConfiguration.approvedMonthlyTrialDurationHours,
    androidPackageName: 'br.com.example.development',
  );

  test('link específico da Google Play valida package e produto', () {
    final Uri uri = PremiumSubscriptionUri.create(
      configuration: configuration,
      subscriptionId: 'meu_gestor_premium',
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'play.google.com');
    expect(uri.path, '/store/account/subscriptions');
    expect(uri.queryParameters, <String, String>{
      'sku': 'meu_gestor_premium',
      'package': 'br.com.example.development',
    });
  });

  test('produto desconhecido ou package inválido usa central geral segura', () {
    expect(
      PremiumSubscriptionUri.create(
        configuration: configuration,
        subscriptionId: 'unknown.product',
      ).queryParameters,
      isEmpty,
    );
    expect(
      PremiumSubscriptionUri.create(
        configuration: const PremiumProductCatalogConfiguration(
          subscriptionId:
              PremiumProductCatalogConfiguration.approvedSubscriptionId,
          monthlyBasePlanId:
              PremiumProductCatalogConfiguration.approvedMonthlyBasePlanId,
          annualBasePlanId:
              PremiumProductCatalogConfiguration.approvedAnnualBasePlanId,
          monthlyTrialOfferId:
              PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId,
          monthlyTrialDurationHours: PremiumProductCatalogConfiguration
              .approvedMonthlyTrialDurationHours,
          androidPackageName: 'invalid package',
        ),
        subscriptionId: 'meu_gestor_premium',
      ).queryParameters,
      isEmpty,
    );
  });
}
