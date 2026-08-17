import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';

abstract interface class PremiumPurchaseVerificationGateway {
  bool get isAvailable;

  /// Recebe a evidência somente em memória. O backend deve verificar a compra
  /// contra a Google Play; não devolve nem armazena o payload no cliente.
  Future<PremiumPurchaseVerificationResult> verify({
    required PremiumPurchaseVerificationRequest request,
  });
}
