import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_billing_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/premium_products_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/premium_purchase_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_premium_billing.dart';
import '../../../support/fake_premium_entitlement_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('catálogo fica em preparação sem backend e não consulta loja', () async {
    final _BillingContext context = await _context(backendAvailable: false);
    addTearDown(context.dispose);

    final PremiumProductsState state = await context.container.read(
      premiumProductsControllerProvider.future,
    );
    expect(state.status, PremiumProductsStatus.preparation);
    expect(context.billing.startCalls, 0);
  });

  test(
    'catálogo mostra dois base plans válidos somente quando loja responde',
    () async {
      final _BillingContext context = await _context();
      addTearDown(context.dispose);

      final PremiumProductsState state = await context.container.read(
        premiumProductsControllerProvider.future,
      );
      expect(state.status, PremiumProductsStatus.ready);
      expect(state.products, hasLength(2));
      expect(state.canPurchase, isTrue);
    },
  );

  test('catálogo recusa resposta incompleta ou loja indisponível', () async {
    final _BillingContext incomplete = await _context();
    incomplete.billing.products = incomplete.billing.products.take(1).toList();
    final PremiumProductsState incompleteState = await incomplete.container
        .read(premiumProductsControllerProvider.future);
    expect(incompleteState.status, PremiumProductsStatus.unavailable);
    incomplete.dispose();

    final _BillingContext unavailable = await _context();
    unavailable.billing.storeAvailable = false;
    final PremiumProductsState unavailableState = await unavailable.container
        .read(premiumProductsControllerProvider.future);
    expect(unavailableState.status, PremiumProductsStatus.unavailable);
    unavailable.dispose();
  });

  test('compra bloqueada sem verificador não abre a loja', () async {
    final _BillingContext context = await _context(backendAvailable: false);
    addTearDown(context.dispose);
    final PremiumStoreProduct product = context.billing.products.first;

    await context.container
        .read(premiumPurchaseControllerProvider.notifier)
        .purchase(product);

    expect(context.billing.startCalls, 0);
    expect(
      context.container.read(premiumPurchaseControllerProvider).phase,
      PremiumPurchasePhase.error,
    );
  });

  test('múltiplos toques iniciam somente uma compra', () async {
    final _BillingContext context = await _context();
    addTearDown(context.dispose);
    final PremiumStoreProduct product = context.billing.products.first;

    await Future.wait<void>(<Future<void>>[
      context.container
          .read(premiumPurchaseControllerProvider.notifier)
          .purchase(product),
      context.container
          .read(premiumPurchaseControllerProvider.notifier)
          .purchase(product),
    ]);
    expect(context.billing.startCalls, 1);
  });

  test('pagamento pendente não verifica, conclui ou libera Premium', () async {
    final _BillingContext context = await _context();
    addTearDown(context.dispose);
    context.billing.emit(_update(PremiumPurchaseUpdateStatus.pending));
    await _flush();

    expect(context.verifier.calls, 0);
    expect(
      context.container.read(premiumPurchaseControllerProvider).phase,
      PremiumPurchasePhase.pending,
    );
  });

  test(
    'sucesso local só ativa após verificação e releitura do servidor',
    () async {
      final _BillingContext context = await _context(
        entitlement: syntheticPremiumEntitlement(),
      );
      addTearDown(context.dispose);
      await context.container
          .read(premiumPurchaseControllerProvider.notifier)
          .purchase(context.billing.products.first);
      context.billing.emit(_update(PremiumPurchaseUpdateStatus.purchased));
      await _flush();

      expect(context.verifier.calls, 1);
      expect(
        context.verifier.lastRequest?.subscriptionId,
        'meu_gestor_premium',
      );
      expect(context.verifier.lastRequest?.requestedBasePlanId, 'mensal');
      expect(context.verifier.lastRequest?.requestedOfferId, 'teste-3d');
      expect(context.verifier.receivedPayload, 'synthetic-token');
      expect(
        context.container.read(premiumPurchaseControllerProvider).phase,
        PremiumPurchasePhase.active,
      );
    },
  );

  test('token não aparece no estado nem em diagnóstico de compra', () async {
    final _BillingContext context = await _context();
    addTearDown(context.dispose);
    context.verifier.result = PremiumPurchaseVerificationResult.denied;
    context.billing.emit(_update(PremiumPurchaseUpdateStatus.purchased));
    await _flush();

    expect(
      context.container.read(premiumPurchaseControllerProvider).message,
      isNot(contains('synthetic-token')),
    );
  });

  test(
    'verificação negada ou entitlement ausente mantém acesso fechado',
    () async {
      final _BillingContext denied = await _context();
      denied.verifier.result = PremiumPurchaseVerificationResult.denied;
      denied.billing.emit(_update(PremiumPurchaseUpdateStatus.purchased));
      await _flush();
      expect(
        denied.container.read(premiumPurchaseControllerProvider).phase,
        PremiumPurchasePhase.error,
      );
      denied.dispose();

      final _BillingContext absent = await _context();
      absent.billing.emit(_update(PremiumPurchaseUpdateStatus.restored));
      await _flush();
      expect(
        absent.container.read(premiumPurchaseControllerProvider).phase,
        PremiumPurchasePhase.error,
      );
      absent.dispose();
    },
  );

  test('cancelamento e restauração têm estado seguro e idempotente', () async {
    final _BillingContext context = await _context();
    addTearDown(context.dispose);
    context.billing.emit(_update(PremiumPurchaseUpdateStatus.cancelled));
    await _flush();
    expect(
      context.container.read(premiumPurchaseControllerProvider).phase,
      PremiumPurchasePhase.cancelled,
    );

    await context.container
        .read(premiumPurchaseControllerProvider.notifier)
        .restore();
    expect(context.billing.restoreCalls, 1);
  });

  test('perda de conexão na restauração mantém o Premium fechado', () async {
    final _BillingContext context = await _context();
    addTearDown(context.dispose);
    context.billing.nextError = StateError('synthetic-offline');

    await context.container
        .read(premiumPurchaseControllerProvider.notifier)
        .restore();

    expect(context.billing.restoreCalls, 1);
    expect(context.verifier.calls, 0);
    expect(
      context.container.read(premiumPurchaseControllerProvider).phase,
      PremiumPurchasePhase.error,
    );
  });

  test(
    'atualização de outro produto não abre verificação nem acesso',
    () async {
      final _BillingContext context = await _context();
      addTearDown(context.dispose);
      context.billing.emit(
        PremiumPurchaseUpdate(
          subscriptionId: 'other_subscription',
          status: PremiumPurchaseUpdateStatus.purchased,
          verificationPayload: 'synthetic-other-payload',
        ),
      );
      await _flush();

      expect(context.verifier.calls, 0);
    },
  );
}

PremiumPurchaseUpdate _update(PremiumPurchaseUpdateStatus status) =>
    PremiumPurchaseUpdate(
      subscriptionId: 'meu_gestor_premium',
      status: status,
      verificationPayload: 'synthetic-token',
    );

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _BillingContext {
  const _BillingContext({
    required this.container,
    required this.auth,
    required this.billing,
    required this.verifier,
    required this.identity,
    required this.profileGate,
    required this.purchase,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakePremiumBillingGateway billing;
  final FakePremiumPurchaseVerificationGateway verifier;
  final FakePremiumPurchaseIdentityGateway identity;
  final ProviderSubscription<AsyncValue<ProfileGateState>> profileGate;
  final ProviderSubscription<PremiumPurchaseState> purchase;

  void dispose() {
    profileGate.close();
    purchase.close();
    container.dispose();
    unawaited(auth.close());
    unawaited(billing.close());
  }
}

Future<_BillingContext> _context({
  bool backendAvailable = true,
  PremiumEntitlement? entitlement,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakePremiumBillingGateway billing = FakePremiumBillingGateway();
  final FakePremiumPurchaseVerificationGateway verifier =
      FakePremiumPurchaseVerificationGateway(available: backendAvailable);
  final FakePremiumPurchaseIdentityGateway identity =
      FakePremiumPurchaseIdentityGateway(available: backendAvailable);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      premiumEntitlementRepositoryProvider.overrideWithValue(
        FakePremiumEntitlementRepository(entitlement: entitlement),
      ),
      premiumBillingGatewayProvider.overrideWithValue(billing),
      premiumPurchaseVerificationGatewayProvider.overrideWithValue(verifier),
      premiumPurchaseIdentityGatewayProvider.overrideWithValue(identity),
      premiumBillingAppCheckPreparedProvider.overrideWithValue(true),
      premiumProductCatalogConfigurationProvider.overrideWithValue(
        const PremiumProductCatalogConfiguration(
          subscriptionId:
              PremiumProductCatalogConfiguration.approvedSubscriptionId,
          monthlyBasePlanId:
              PremiumProductCatalogConfiguration.approvedMonthlyBasePlanId,
          annualBasePlanId:
              PremiumProductCatalogConfiguration.approvedAnnualBasePlanId,
          monthlyTrialOfferId:
              PremiumProductCatalogConfiguration.approvedMonthlyTrialOfferId,
          monthlyTrialDurationHours: PremiumProductCatalogConfiguration
              .approvedMonthlyTrialDurationHours,
          androidPackageName: 'br.com.example.development',
        ),
      ),
    ],
  );
  final Completer<void> ready = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> profileGate =
      container.listen(profileGateControllerProvider, (_, next) {
        if (next.value?.isTerminal == true && !ready.isCompleted) {
          ready.complete();
        }
      }, fireImmediately: true);
  await ready.future.timeout(const Duration(seconds: 2));
  final ProviderSubscription<PremiumPurchaseState> purchase = container.listen(
    premiumPurchaseControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  return _BillingContext(
    container: container,
    auth: auth,
    billing: billing,
    verifier: verifier,
    identity: identity,
    profileGate: profileGate,
    purchase: purchase,
  );
}
