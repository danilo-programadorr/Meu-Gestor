import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

void main() {
  const PremiumProductCatalogConfiguration valid =
      PremiumProductCatalogConfiguration(
        monthlyProductId: 'premium.monthly',
        annualProductId: 'premium.annual',
        androidPackageName: 'br.com.example.development',
      );

  test('catálogo mensal e anual válido tem IDs únicos', () {
    expect(valid.hasConfiguredProducts, isTrue);
    expect(valid.productIdFor(PremiumPlan.monthly), 'premium.monthly');
    expect(valid.productIdFor(PremiumPlan.annual), 'premium.annual');
    expect(valid.productIdFor(PremiumPlan.free), isNull);
  });

  test('catálogo falha fechado para IDs ausentes, inválidos ou duplicados', () {
    for (final PremiumProductCatalogConfiguration value
        in <PremiumProductCatalogConfiguration>[
          const PremiumProductCatalogConfiguration(
            monthlyProductId: '',
            annualProductId: 'premium.annual',
            androidPackageName: '',
          ),
          const PremiumProductCatalogConfiguration(
            monthlyProductId: 'PREMIUM',
            annualProductId: 'premium.annual',
            androidPackageName: '',
          ),
          const PremiumProductCatalogConfiguration(
            monthlyProductId: 'premium.same',
            annualProductId: 'premium.same',
            androidPackageName: '',
          ),
        ]) {
      expect(value.hasConfiguredProducts, isFalse);
    }
  });

  test('package Android é validado antes de deep link específico', () {
    expect(valid.hasValidAndroidPackage, isTrue);
    expect(
      const PremiumProductCatalogConfiguration(
        monthlyProductId: 'premium.monthly',
        annualProductId: 'premium.annual',
        androidPackageName: 'invalid package',
      ).hasValidAndroidPackage,
      isFalse,
    );
  });

  test('produto não aceita plano free, preço ou moeda incompletos', () {
    expect(
      () => PremiumStoreProduct(
        plan: PremiumPlan.free,
        productId: 'premium.monthly',
        title: 'Premium',
        description: '',
        localizedPrice: 'R\$ 9,90',
        currencyCode: 'BRL',
        periodLabel: 'Mensal',
      ),
      throwsArgumentError,
    );
    expect(
      () => PremiumStoreProduct(
        plan: PremiumPlan.monthly,
        productId: 'premium.monthly',
        title: 'Premium',
        description: '',
        localizedPrice: '',
        currencyCode: 'BR',
        periodLabel: 'Mensal',
      ),
      throwsArgumentError,
    );
  });

  test('compra só pode iniciar com todos os pré-requisitos reais', () {
    const PremiumBillingAvailability unavailable = PremiumBillingAvailability(
      storeAvailable: true,
      productsConfigured: true,
      backendVerificationAvailable: false,
      identityAvailable: true,
      appCheckPrepared: true,
      environmentValid: true,
      eligibleUser: true,
    );
    expect(unavailable.canStartPurchase, isFalse);
    expect(unavailable.safeMessage, contains('preparação'));

    const PremiumBillingAvailability ready = PremiumBillingAvailability(
      storeAvailable: true,
      productsConfigured: true,
      backendVerificationAvailable: true,
      identityAvailable: true,
      appCheckPrepared: true,
      environmentValid: true,
      eligibleUser: true,
    );
    expect(ready.canStartPurchase, isTrue);
  });
}
