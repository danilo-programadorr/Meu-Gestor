import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

void main() {
  const PremiumProductCatalogConfiguration
  valid = PremiumProductCatalogConfiguration(
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

  PremiumStoreProduct product({
    PremiumPlan plan = PremiumPlan.monthly,
    String? basePlanId,
    String? offerId,
    String offerToken = 'synthetic-store-offer-token',
  }) => PremiumStoreProduct(
    plan: plan,
    subscriptionId: PremiumProductCatalogConfiguration.approvedSubscriptionId,
    basePlanId:
        basePlanId ??
        (plan == PremiumPlan.monthly
            ? PremiumProductCatalogConfiguration.approvedMonthlyBasePlanId
            : PremiumProductCatalogConfiguration.approvedAnnualBasePlanId),
    offerId: offerId,
    offerToken: offerToken,
    title: 'Premium ${plan == PremiumPlan.monthly ? 'mensal' : 'anual'}',
    description: 'Resposta sintética da loja',
    localizedPrice: 'R\$ 9,90',
    currencyCode: 'BRL',
  );

  test('catálogo usa um produto e dois base plans aprovados', () {
    expect(valid.hasConfiguredProducts, isTrue);
    expect(valid.matchesApprovedCommercialModel, isTrue);
    expect(valid.subscriptionIdFor(PremiumPlan.monthly), 'meu_gestor_premium');
    expect(valid.subscriptionIdFor(PremiumPlan.annual), 'meu_gestor_premium');
    expect(valid.subscriptionIdFor(PremiumPlan.free), isNull);
    expect(valid.basePlanIdFor(PremiumPlan.monthly), 'mensal');
    expect(valid.basePlanIdFor(PremiumPlan.annual), 'anual');
    expect(valid.monthlyTrialDurationHours, 72);
  });

  test('catálogo falha fechado para IDs ausentes, inválidos ou duplicados', () {
    for (final PremiumProductCatalogConfiguration value
        in <PremiumProductCatalogConfiguration>[
          const PremiumProductCatalogConfiguration(
            subscriptionId: '',
            monthlyBasePlanId: 'mensal',
            annualBasePlanId: 'anual',
            monthlyTrialOfferId: 'teste-3d',
            monthlyTrialDurationHours: 72,
            androidPackageName: '',
          ),
          const PremiumProductCatalogConfiguration(
            subscriptionId: 'meu_gestor_premium',
            monthlyBasePlanId: 'mensal',
            annualBasePlanId: 'mensal',
            monthlyTrialOfferId: 'teste-3d',
            monthlyTrialDurationHours: 72,
            androidPackageName: '',
          ),
          const PremiumProductCatalogConfiguration(
            subscriptionId: 'meu_gestor_premium',
            monthlyBasePlanId: 'mensal',
            annualBasePlanId: 'anual',
            monthlyTrialOfferId: 'oferta invalida',
            monthlyTrialDurationHours: 72,
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
      ).hasValidAndroidPackage,
      isFalse,
    );
  });

  test('seleciona oferta de teste mensal da loja e plano anual base', () {
    final List<PremiumStoreProduct> selected = valid
        .selectDisplayProducts(<PremiumStoreProduct>[
          product(offerToken: 'monthly-base-token'),
          product(
            offerId:
                PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId,
            offerToken: 'monthly-trial-token',
          ),
          product(plan: PremiumPlan.annual, offerToken: 'annual-base-token'),
        ]);

    expect(selected, hasLength(2));
    expect(selected.first.offerId, 'teste-3d');
    expect(selected.last.plan, PremiumPlan.annual);
  });

  test('recusa oferta anual, seleção desconhecida ou duplicada', () {
    expect(
      valid.selectDisplayProducts(<PremiumStoreProduct>[
        product(offerToken: 'monthly-base-token'),
        product(plan: PremiumPlan.annual, offerToken: 'annual-base-token'),
        product(basePlanId: 'outro', offerToken: 'unknown-base-plan-token'),
      ]),
      isEmpty,
    );
    expect(
      valid.selectDisplayProducts(<PremiumStoreProduct>[
        product(offerToken: 'monthly-base-token'),
        product(offerToken: 'duplicate-monthly-base-token'),
        product(plan: PremiumPlan.annual, offerToken: 'annual-base-token'),
      ]),
      isEmpty,
    );
  });

  test('produto não aceita plano free, token, preço ou moeda incompletos', () {
    expect(
      () => PremiumStoreProduct(
        plan: PremiumPlan.free,
        subscriptionId: 'meu_gestor_premium',
        basePlanId: 'mensal',
        offerToken: 'synthetic-offer-token',
        title: 'Premium',
        description: '',
        localizedPrice: 'R\$ 9,90',
        currencyCode: 'BRL',
      ),
      throwsArgumentError,
    );
    expect(
      () => PremiumStoreProduct(
        plan: PremiumPlan.monthly,
        subscriptionId: 'meu_gestor_premium',
        basePlanId: 'mensal',
        offerToken: '',
        title: 'Premium',
        description: '',
        localizedPrice: '',
        currencyCode: 'BR',
      ),
      throwsArgumentError,
    );
  });

  test('pedido de verificação não carrega relógio, preço ou offer token', () {
    final PremiumPurchaseVerificationRequest request =
        PremiumPurchaseVerificationRequest(
          subscriptionId: 'meu_gestor_premium',
          origin: PremiumPurchaseVerificationOrigin.purchase,
          verificationPayload: 'synthetic-purchase-payload',
          requestedBasePlanId: 'mensal',
          requestedOfferId: 'teste-3d',
        );

    expect(request.subscriptionId, 'meu_gestor_premium');
    expect(request.requestedBasePlanId, 'mensal');
    expect(request.requestedOfferId, 'teste-3d');
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
