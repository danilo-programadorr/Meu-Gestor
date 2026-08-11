import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

abstract interface class PremiumSubscriptionManagement {
  Future<bool> open({String? productId});
}

abstract final class PremiumSubscriptionUri {
  static Uri create({
    required PremiumProductCatalogConfiguration configuration,
    String? productId,
  }) {
    final bool knownProduct =
        productId != null &&
        (configuration.productIdFor(PremiumPlan.monthly) == productId ||
            configuration.productIdFor(PremiumPlan.annual) == productId);
    if (knownProduct && configuration.hasValidAndroidPackage) {
      return Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        <String, String>{
          'sku': productId,
          'package': configuration.androidPackageName,
        },
      );
    }
    return Uri.https('play.google.com', '/store/account/subscriptions');
  }
}
