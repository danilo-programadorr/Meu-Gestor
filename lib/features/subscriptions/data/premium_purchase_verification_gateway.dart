import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_verification_gateway.dart';

/// Barreira explícita até existir endpoint autenticado e verificação Play real.
final class DisabledPremiumPurchaseVerificationGateway
    implements PremiumPurchaseVerificationGateway {
  const DisabledPremiumPurchaseVerificationGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<PremiumPurchaseVerificationResult> verify({
    required PremiumPurchaseVerificationRequest request,
  }) async => PremiumPurchaseVerificationResult.unavailable;
}
