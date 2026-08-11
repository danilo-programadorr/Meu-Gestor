import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_subscription_management.dart';

void main() {
  const PremiumProductCatalogConfiguration configuration =
      PremiumProductCatalogConfiguration(
        monthlyProductId: 'premium.monthly',
        annualProductId: 'premium.annual',
        androidPackageName: 'br.com.example.development',
      );

  test('link específico da Google Play valida package e produto', () {
    final Uri uri = PremiumSubscriptionUri.create(
      configuration: configuration,
      productId: 'premium.monthly',
    );
    expect(uri.scheme, 'https');
    expect(uri.host, 'play.google.com');
    expect(uri.path, '/store/account/subscriptions');
    expect(uri.queryParameters, <String, String>{
      'sku': 'premium.monthly',
      'package': 'br.com.example.development',
    });
  });

  test('produto desconhecido ou package inválido usa central geral segura', () {
    expect(
      PremiumSubscriptionUri.create(
        configuration: configuration,
        productId: 'unknown.product',
      ).queryParameters,
      isEmpty,
    );
    expect(
      PremiumSubscriptionUri.create(
        configuration: const PremiumProductCatalogConfiguration(
          monthlyProductId: 'premium.monthly',
          annualProductId: 'premium.annual',
          androidPackageName: 'invalid package',
        ),
        productId: 'premium.monthly',
      ).queryParameters,
      isEmpty,
    );
  });
}
