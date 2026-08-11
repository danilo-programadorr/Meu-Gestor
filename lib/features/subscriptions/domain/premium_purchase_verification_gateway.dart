import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';

abstract interface class PremiumPurchaseVerificationGateway {
  bool get isAvailable;

  /// Recebe o payload somente em memória e nunca devolve nem armazena o token.
  Future<PremiumPurchaseVerificationResult> verify({
    required String productId,
    required String verificationPayload,
  });
}
