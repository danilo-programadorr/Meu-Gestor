import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

final class PremiumProductMapper {
  const PremiumProductMapper._();

  static PremiumStoreProduct map({
    required ProductDetails details,
    required PremiumPlan plan,
    required String subscriptionId,
    required String basePlanId,
    required String offerToken,
    String? offerId,
  }) {
    if (details.id.trim().isEmpty ||
        details.title.trim().isEmpty ||
        details.price.trim().isEmpty ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(details.currencyCode)) {
      throw const FormatException('Resposta de produto incompleta.');
    }
    return PremiumStoreProduct(
      plan: plan,
      subscriptionId: subscriptionId,
      basePlanId: basePlanId,
      offerId: offerId,
      offerToken: offerToken,
      title: details.title,
      description: details.description,
      localizedPrice: details.price,
      currencyCode: details.currencyCode,
      offerLabel:
          offerId ==
              PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId
          ? 'Teste gratuito por 3 dias, sujeito à elegibilidade na Google Play.'
          : null,
    );
  }
}
