import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_subscription_management.dart';
import 'package:url_launcher/url_launcher.dart';

final class GooglePlaySubscriptionManagement
    implements PremiumSubscriptionManagement {
  const GooglePlaySubscriptionManagement({required this.configuration});

  final PremiumProductCatalogConfiguration configuration;

  @override
  Future<bool> open({String? productId}) {
    final Uri destination = PremiumSubscriptionUri.create(
      configuration: configuration,
      productId: productId,
    );
    return launchUrl(destination, mode: LaunchMode.externalApplication);
  }
}
