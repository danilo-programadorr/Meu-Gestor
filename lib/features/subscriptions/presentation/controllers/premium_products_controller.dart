import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_billing_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';

enum PremiumProductsStatus { loading, preparation, ready, unavailable }

final class PremiumProductsState {
  const PremiumProductsState({
    required this.status,
    required this.availability,
    required this.products,
    required this.message,
  });

  final PremiumProductsStatus status;
  final PremiumBillingAvailability availability;
  final List<PremiumStoreProduct> products;
  final String message;

  bool get canPurchase => availability.canStartPurchase && products.isNotEmpty;
}

final AsyncNotifierProvider<PremiumProductsController, PremiumProductsState>
premiumProductsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      PremiumProductsController,
      PremiumProductsState
    >(PremiumProductsController.new);

final class PremiumProductsController
    extends AsyncNotifier<PremiumProductsState> {
  @override
  Future<PremiumProductsState> build() => _load();

  Future<void> retry() async {
    state = const AsyncLoading<PremiumProductsState>();
    state = AsyncData<PremiumProductsState>(await _load());
  }

  Future<PremiumProductsState> _load() async {
    final PremiumBillingAvailability availability = ref.read(
      premiumBillingAvailabilityProvider,
    );
    if (!availability.productsConfigured ||
        !availability.backendVerificationAvailable ||
        !availability.identityAvailable) {
      return PremiumProductsState(
        status: PremiumProductsStatus.preparation,
        availability: availability,
        products: const <PremiumStoreProduct>[],
        message: availability.safeMessage,
      );
    }
    try {
      final bool available = await ref
          .read(premiumBillingGatewayProvider)
          .isStoreAvailable();
      final PremiumBillingAvailability checked = PremiumBillingAvailability(
        storeAvailable: available,
        productsConfigured: availability.productsConfigured,
        backendVerificationAvailable: availability.backendVerificationAvailable,
        identityAvailable: availability.identityAvailable,
        appCheckPrepared: availability.appCheckPrepared,
        environmentValid: availability.environmentValid,
        eligibleUser: availability.eligibleUser,
      );
      if (!available) {
        return PremiumProductsState(
          status: PremiumProductsStatus.unavailable,
          availability: checked,
          products: const <PremiumStoreProduct>[],
          message: checked.safeMessage,
        );
      }
      final List<PremiumStoreProduct> products = await ref
          .read(premiumBillingGatewayProvider)
          .loadProducts(
            configuration: ref.read(premiumProductCatalogConfigurationProvider),
          );
      if (products.length != 2) {
        return PremiumProductsState(
          status: PremiumProductsStatus.unavailable,
          availability: checked,
          products: const <PremiumStoreProduct>[],
          message:
              'Os planos Premium ainda não estão disponíveis na Google Play.',
        );
      }
      return PremiumProductsState(
        status: PremiumProductsStatus.ready,
        availability: checked,
        products: List<PremiumStoreProduct>.unmodifiable(products),
        message: checked.safeMessage,
      );
    } on Object {
      return PremiumProductsState(
        status: PremiumProductsStatus.unavailable,
        availability: availability,
        products: const <PremiumStoreProduct>[],
        message: 'Não foi possível consultar os planos agora. Tente novamente.',
      );
    }
  }
}
