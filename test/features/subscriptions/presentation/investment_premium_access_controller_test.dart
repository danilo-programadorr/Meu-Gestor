import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_premium_entitlement_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test(
    'active confirmado produz acesso integral nas duas capabilities',
    () async {
      final _AccessContext context = await _context(
        entitlement: syntheticPremiumEntitlement(),
      );
      addTearDown(context.dispose);

      expect(context.state.status, InvestmentPremiumAccessStatus.full);
      expect(context.state.canReadManual, isTrue);
      expect(context.state.canMutateManual, isTrue);
      expect(context.state.canReadIncome, isTrue);
      expect(context.state.canMutateIncome, isTrue);
    },
  );

  test('trial, grace e cancelado vigente mantêm acesso integral', () async {
    for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
      PremiumEntitlementStatus.trialing,
      PremiumEntitlementStatus.gracePeriod,
      PremiumEntitlementStatus.cancelled,
    ]) {
      final _AccessContext context = await _context(
        entitlement: syntheticPremiumEntitlement(status: status),
      );
      expect(context.state.status, InvestmentPremiumAccessStatus.full);
      context.dispose();
    }
  });

  test(
    'perda do Premium mantém somente leitura e preserva capabilities',
    () async {
      for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
        PremiumEntitlementStatus.expired,
        PremiumEntitlementStatus.accountHold,
        PremiumEntitlementStatus.paused,
        PremiumEntitlementStatus.revoked,
        PremiumEntitlementStatus.refunded,
      ]) {
        final _AccessContext context = await _context(
          entitlement: syntheticPremiumEntitlement(status: status),
        );
        expect(
          context.state.status,
          InvestmentPremiumAccessStatus.readOnly,
          reason: status.name,
        );
        expect(context.state.canReadManual, isTrue);
        expect(context.state.canMutateManual, isFalse);
        expect(context.state.canReadIncome, isTrue);
        expect(context.state.canMutateIncome, isFalse);
        context.dispose();
      }
    },
  );

  test(
    'cancelado no vencimento passa imediatamente a somente leitura',
    () async {
      final _AccessContext context = await _context(
        entitlement: syntheticPremiumEntitlement(
          status: PremiumEntitlementStatus.cancelled,
          currentPeriodEndsAt: DateTime.utc(2026, 8, 10, 12),
        ),
      );
      addTearDown(context.dispose);
      expect(context.state.status, InvestmentPremiumAccessStatus.readOnly);
    },
  );

  test('ausência e pending são negados sem carregar dados Premium', () async {
    final _AccessContext absent = await _context();
    expect(absent.state.status, InvestmentPremiumAccessStatus.denied);
    expect(absent.state.problem, InvestmentPremiumAccessProblem.missing);
    absent.dispose();

    final _AccessContext pending = await _context(
      entitlement: syntheticPremiumEntitlement(
        status: PremiumEntitlementStatus.pending,
      ),
    );
    expect(pending.state.status, InvestmentPremiumAccessStatus.denied);
    expect(pending.state.problem, InvestmentPremiumAccessProblem.pending);
    pending.dispose();
  });

  test('capability ausente nega apenas a área correspondente', () async {
    final _AccessContext context = await _context(
      entitlement: syntheticPremiumEntitlement(
        capabilities: const <PremiumCapability>{
          PremiumCapability.investmentsManual,
        },
      ),
    );
    addTearDown(context.dispose);
    expect(context.state.canMutateManual, isTrue);
    expect(context.state.canReadIncome, isFalse);
    expect(context.state.canMutateIncome, isFalse);
  });

  test('cache e escrita pendente nunca confirmam acesso', () async {
    final FakePremiumEntitlementRepository repository =
        FakePremiumEntitlementRepository(
            entitlement: syntheticPremiumEntitlement(),
          )
          ..isFromServer = false
          ..hasPendingWrites = true;
    final _AccessContext context = await _context(repository: repository);
    addTearDown(context.dispose);
    expect(
      context.state.status,
      InvestmentPremiumAccessStatus.confirmationError,
    );
    expect(context.state.canMutateManual, isFalse);
  });

  test('falha do servidor fecha mutações e retry recupera acesso', () async {
    final FakePremiumEntitlementRepository repository =
        FakePremiumEntitlementRepository(
            entitlement: syntheticPremiumEntitlement(),
          )
          ..nextFailure = const PremiumEntitlementFailure(
            kind: PremiumEntitlementFailureKind.unavailable,
            safeMessage: 'Confirmação indisponível.',
            code: 'synthetic_unavailable',
          );
    final _AccessContext context = await _context(repository: repository);
    addTearDown(context.dispose);
    expect(
      context.state.status,
      InvestmentPremiumAccessStatus.confirmationError,
    );

    await context.container
        .read(investmentPremiumAccessControllerProvider.notifier)
        .retry();
    expect(
      context.container
          .read(investmentPremiumAccessControllerProvider)
          .requireValue
          .status,
      InvestmentPremiumAccessStatus.full,
    );
  });

  test('novo entitlement válido restaura acesso sem migrar dados', () async {
    final FakePremiumEntitlementRepository repository =
        FakePremiumEntitlementRepository(
          entitlement: syntheticPremiumEntitlement(
            status: PremiumEntitlementStatus.expired,
          ),
        );
    final _AccessContext context = await _context(repository: repository);
    addTearDown(context.dispose);
    expect(context.state.status, InvestmentPremiumAccessStatus.readOnly);

    repository.entitlement = syntheticPremiumEntitlement();
    await context.container
        .read(investmentPremiumAccessControllerProvider.notifier)
        .retry();

    expect(context.state.status, InvestmentPremiumAccessStatus.full);
    expect(context.state.canMutateManual, isTrue);
    expect(context.state.canMutateIncome, isTrue);
  });

  test('resposta tardia é descartada após troca de sessão', () async {
    final Completer<void> barrier = Completer<void>();
    final FakePremiumEntitlementRepository repository =
        FakePremiumEntitlementRepository(
          entitlement: syntheticPremiumEntitlement(),
        )..readBarrier = barrier;
    final _AccessContext context = await _context(
      repository: repository,
      waitForAccess: false,
    );
    addTearDown(context.dispose);
    context.auth.emit(null);
    await Future<void>.delayed(Duration.zero);
    barrier.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final AsyncValue<InvestmentPremiumAccessState> value = context.container
        .read(investmentPremiumAccessControllerProvider);
    expect(value.value?.canMutateManual ?? false, isFalse);
  });
}

final class _AccessContext {
  const _AccessContext({
    required this.container,
    required this.auth,
    required this.gate,
    required this.access,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate;
  final ProviderSubscription<AsyncValue<InvestmentPremiumAccessState>> access;

  InvestmentPremiumAccessState get state =>
      container.read(investmentPremiumAccessControllerProvider).requireValue;

  void dispose() {
    access.close();
    gate.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_AccessContext> _context({
  PremiumEntitlement? entitlement,
  FakePremiumEntitlementRepository? repository,
  bool waitForAccess = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakePremiumEntitlementRepository premiumRepository =
      repository ?? FakePremiumEntitlementRepository(entitlement: entitlement);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      premiumEntitlementRepositoryProvider.overrideWithValue(premiumRepository),
      premiumAccessReferenceClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 10, 12),
      ),
    ],
  );
  final Completer<void> gateReady = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate = container
      .listen(profileGateControllerProvider, (_, next) {
        if (next.value?.isTerminal == true && !gateReady.isCompleted) {
          gateReady.complete();
        }
      }, fireImmediately: true);
  await gateReady.future.timeout(const Duration(seconds: 2));

  final Completer<void> accessReady = Completer<void>();
  final ProviderSubscription<AsyncValue<InvestmentPremiumAccessState>> access =
      container.listen(investmentPremiumAccessControllerProvider, (_, next) {
        if (!next.isLoading && !accessReady.isCompleted) {
          accessReady.complete();
        }
      }, fireImmediately: true);
  if (waitForAccess) {
    await accessReady.future.timeout(const Duration(seconds: 2));
  }
  return _AccessContext(
    container: container,
    auth: auth,
    gate: gate,
    access: access,
  );
}
