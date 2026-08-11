import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

final class PremiumProductMapper {
  const PremiumProductMapper._();

  static PremiumStoreProduct map({
    required ProductDetails details,
    required PremiumPlan plan,
  }) {
    if (details.id.trim().isEmpty ||
        details.title.trim().isEmpty ||
        details.price.trim().isEmpty ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(details.currencyCode)) {
      throw const FormatException('Resposta de produto incompleta.');
    }
    return PremiumStoreProduct(
      plan: plan,
      productId: details.id,
      title: details.title,
      description: details.description,
      localizedPrice: details.price,
      currencyCode: details.currencyCode,
      // A periodicidade é parte do catálogo aprovado, nunca um valor monetário.
      periodLabel: plan == PremiumPlan.monthly ? 'Mensal' : 'Anual',
    );
  }
}
