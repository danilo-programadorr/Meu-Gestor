import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_identity_gateway.dart';

final class DisabledPremiumPurchaseIdentityGateway
    implements PremiumPurchaseIdentityGateway {
  const DisabledPremiumPurchaseIdentityGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<String?> currentObfuscatedAccountId() async => null;
}
