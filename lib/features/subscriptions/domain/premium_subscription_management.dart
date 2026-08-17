import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';

abstract interface class PremiumSubscriptionManagement {
  Future<bool> open({String? subscriptionId});
}

abstract final class PremiumSubscriptionUri {
  static Uri create({
    required PremiumProductCatalogConfiguration configuration,
    String? subscriptionId,
  }) {
    final bool knownProduct =
        subscriptionId != null &&
        subscriptionId == configuration.subscriptionId;
    if (knownProduct && configuration.hasValidAndroidPackage) {
      return Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        <String, String>{
          'sku': subscriptionId,
          'package': configuration.androidPackageName,
        },
      );
    }
    return Uri.https('play.google.com', '/store/account/subscriptions');
  }
}
