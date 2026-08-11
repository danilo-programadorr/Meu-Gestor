import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_billing_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

enum PremiumPurchasePhase {
  idle,
  starting,
  pending,
  verifying,
  active,
  cancelled,
  error,
}

final class PremiumPurchaseState {
  const PremiumPurchaseState({required this.phase, required this.message});

  const PremiumPurchaseState.idle()
    : phase = PremiumPurchasePhase.idle,
      message = '';

  final PremiumPurchasePhase phase;
  final String message;

  bool get isBusy =>
      phase == PremiumPurchasePhase.starting ||
      phase == PremiumPurchasePhase.pending ||
      phase == PremiumPurchasePhase.verifying;
}

final NotifierProvider<PremiumPurchaseController, PremiumPurchaseState>
premiumPurchaseControllerProvider =
    NotifierProvider.autoDispose<
      PremiumPurchaseController,
      PremiumPurchaseState
    >(PremiumPurchaseController.new);

final class PremiumPurchaseController extends Notifier<PremiumPurchaseState> {
  StreamSubscription<List<PremiumPurchaseUpdate>>? _subscription;
  int _operation = 0;

  @override
  PremiumPurchaseState build() {
    _subscription = ref
        .read(premiumBillingGatewayProvider)
        .purchaseUpdates
        .listen(_handleUpdates, onError: (_) => _setError());
    ref.onDispose(() {
      _operation += 1;
      _subscription?.cancel();
    });
    return const PremiumPurchaseState.idle();
  }

  Future<void> purchase(PremiumStoreProduct product) async {
    if (state.isBusy) return;
    final PremiumBillingAvailability availability = ref.read(
      premiumBillingAvailabilityProvider,
    );
    if (!availability.canStartPurchase) {
      state = PremiumPurchaseState(
        phase: PremiumPurchasePhase.error,
        message: availability.safeMessage,
      );
      return;
    }
    final int operation = ++_operation;
    state = const PremiumPurchaseState(
      phase: PremiumPurchasePhase.starting,
      message: 'Abrindo a confirmação segura da Google Play.',
    );
    try {
      final String? obfuscatedAccountId = await ref
          .read(premiumPurchaseIdentityGatewayProvider)
          .currentObfuscatedAccountId();
      if (operation != _operation) return;
      if (obfuscatedAccountId == null || obfuscatedAccountId.isEmpty) {
        _setError(
          'Não foi possível preparar sua identificação de assinatura com segurança.',
        );
        return;
      }
      final bool started = await ref
          .read(premiumBillingGatewayProvider)
          .startSubscription(
            product: product,
            obfuscatedAccountId: obfuscatedAccountId,
          );
      if (operation != _operation) return;
      if (!started) {
        _setError('A Google Play não pôde iniciar a assinatura.');
      }
    } on Object {
      if (operation == _operation) _setError();
    }
  }

  Future<void> restore() async {
    if (state.isBusy) return;
    final PremiumBillingAvailability availability = ref.read(
      premiumBillingAvailabilityProvider,
    );
    if (!availability.backendVerificationAvailable) {
      state = PremiumPurchaseState(
        phase: PremiumPurchasePhase.error,
        message: availability.safeMessage,
      );
      return;
    }
    final int operation = ++_operation;
    state = const PremiumPurchaseState(
      phase: PremiumPurchasePhase.verifying,
      message: 'Consultando compras para restaurar sua assinatura.',
    );
    try {
      await ref.read(premiumBillingGatewayProvider).restorePurchases();
      if (operation == _operation) {
        state = const PremiumPurchaseState(
          phase: PremiumPurchasePhase.idle,
          message: 'Nenhuma assinatura confirmada foi encontrada ainda.',
        );
      }
    } on Object {
      if (operation == _operation) _setError();
    }
  }

  Future<void> _handleUpdates(List<PremiumPurchaseUpdate> updates) async {
    for (final PremiumPurchaseUpdate update in updates) {
      switch (update.status) {
        case PremiumPurchaseUpdateStatus.pending:
          state = const PremiumPurchaseState(
            phase: PremiumPurchasePhase.pending,
            message:
                'Pagamento pendente. O Premium será liberado somente após confirmação do servidor.',
          );
        case PremiumPurchaseUpdateStatus.cancelled:
          state = const PremiumPurchaseState(
            phase: PremiumPurchasePhase.cancelled,
            message:
                'A assinatura não foi concluída. Nenhuma cobrança foi confirmada pelo aplicativo.',
          );
        case PremiumPurchaseUpdateStatus.error:
          _setError('A Google Play informou uma falha na assinatura.');
        case PremiumPurchaseUpdateStatus.purchased ||
            PremiumPurchaseUpdateStatus.restored:
          await _verify(update);
      }
    }
  }

  Future<void> _verify(PremiumPurchaseUpdate update) async {
    if (update.verificationPayload.isEmpty) {
      _setError('Não foi possível validar a assinatura com segurança.');
      return;
    }
    final int operation = ++_operation;
    state = const PremiumPurchaseState(
      phase: PremiumPurchasePhase.verifying,
      message: 'Verificando sua assinatura com o servidor.',
    );
    try {
      final PremiumPurchaseVerificationResult result = await ref
          .read(premiumPurchaseVerificationGatewayProvider)
          .verify(
            productId: update.productId,
            verificationPayload: update.verificationPayload,
          );
      if (operation != _operation) return;
      if (result != PremiumPurchaseVerificationResult.confirmed) {
        _setError(
          result == PremiumPurchaseVerificationResult.unavailable
              ? 'A confirmação do servidor está indisponível. Seu acesso não foi alterado.'
              : 'A assinatura não foi confirmada pelo servidor. Seu acesso não foi alterado.',
        );
        return;
      }
      final String? ownerId = verifiedFinancialOwner(ref);
      if (ownerId == null) {
        _setError('Confirme sua sessão antes de concluir a assinatura.');
        return;
      }
      final PremiumEntitlementReadResult entitlement = await ref
          .read(premiumEntitlementRepositoryProvider)
          .refreshFromServer(ownerId: ownerId);
      if (operation != _operation ||
          !entitlement.isFromServer ||
          entitlement.hasPendingWrites ||
          entitlement.presence != PremiumEntitlementPresence.present) {
        _setError('O Premium ainda aguarda confirmação do servidor.');
        return;
      }
      if (update.pendingCompletePurchase) {
        await ref.read(premiumBillingGatewayProvider).completePurchase(update);
      }
      if (operation != _operation) return;
      ref.invalidate(premiumEntitlementReadProvider(ownerId));
      ref.invalidate(investmentPremiumAccessControllerProvider);
      state = const PremiumPurchaseState(
        phase: PremiumPurchasePhase.active,
        message: 'Premium confirmado pelo servidor.',
      );
    } on Object {
      if (operation == _operation) _setError();
    }
  }

  void _setError([
    String message =
        'Não foi possível concluir a assinatura. Tente novamente mais tarde.',
  ]) {
    state = PremiumPurchaseState(
      phase: PremiumPurchasePhase.error,
      message: message,
    );
  }
}
