import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/closed_test_activation_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_closed_test_activation_repository.dart';
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

  test('ausência em production e pending são negados', () async {
    final _AccessContext absent = await _context(
      environment: AppEnvironment.production,
    );
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

  test(
    'development ativa teste fechado uma vez e relê entitlement do servidor',
    () async {
      final FakePremiumEntitlementRepository premiumRepository =
          FakePremiumEntitlementRepository();
      final FakeClosedTestActivationRepository activationRepository =
          FakeClosedTestActivationRepository()
            ..onActivate = () {
              premiumRepository.entitlement = syntheticPremiumEntitlement(
                capabilities: PremiumCapability.values,
              );
            };
      final _AccessContext context = await _context(
        repository: premiumRepository,
        activationRepository: activationRepository,
      );
      addTearDown(context.dispose);

      expect(activationRepository.calls, 1);
      expect(premiumRepository.refreshCalls, 2);
      expect(context.state.status, InvestmentPremiumAccessStatus.full);
      expect(context.state.isServerConfirmed, isTrue);
    },
  );

  test('usuário não autorizado permanece bloqueado sem loop', () async {
    final FakeClosedTestActivationRepository activationRepository =
        FakeClosedTestActivationRepository()
          ..failure = const ClosedTestActivationFailure(
            kind: ClosedTestActivationFailureKind.notAuthorized,
            safeMessage: 'O acesso ao teste fechado não está disponível.',
            code: 'synthetic_not_authorized',
          );
    final _AccessContext context = await _context(
      activationRepository: activationRepository,
    );
    addTearDown(context.dispose);

    expect(context.state.status, InvestmentPremiumAccessStatus.denied);
    expect(context.state.problem, InvestmentPremiumAccessProblem.missing);
    await context.container
        .read(investmentPremiumAccessControllerProvider.notifier)
        .retry();
    expect(activationRepository.calls, 1);
    expect(context.state.status, InvestmentPremiumAccessStatus.denied);
  });

  test('App Check inválido falha fechado', () async {
    final FakeClosedTestActivationRepository activationRepository =
        FakeClosedTestActivationRepository()
          ..failure = const ClosedTestActivationFailure(
            kind: ClosedTestActivationFailureKind.appCheckRejected,
            safeMessage: 'Não foi possível validar esta instalação.',
            code: 'synthetic_app_check',
          );
    final _AccessContext context = await _context(
      activationRepository: activationRepository,
    );
    addTearDown(context.dispose);

    expect(
      context.state.status,
      InvestmentPremiumAccessStatus.confirmationError,
    );
    expect(context.state.canMutateManual, isFalse);
  });

  test('timeout de ativação falha fechado', () async {
    final FakeClosedTestActivationRepository activationRepository =
        FakeClosedTestActivationRepository()
          ..failure = const ClosedTestActivationFailure(
            kind: ClosedTestActivationFailureKind.timeout,
            safeMessage: 'A ativação demorou demais.',
            code: 'synthetic_timeout',
          );
    final _AccessContext context = await _context(
      activationRepository: activationRepository,
    );
    addTearDown(context.dispose);

    expect(
      context.state.status,
      InvestmentPremiumAccessStatus.confirmationError,
    );
    expect(context.state.canReadManual, isFalse);
  });

  test(
    'resposta tardia da ativação é descartada após troca de sessão',
    () async {
      final Completer<void> activationBarrier = Completer<void>();
      final FakePremiumEntitlementRepository premiumRepository =
          FakePremiumEntitlementRepository();
      final FakeClosedTestActivationRepository activationRepository =
          FakeClosedTestActivationRepository()
            ..barrier = activationBarrier
            ..onActivate = () {
              premiumRepository.entitlement = syntheticPremiumEntitlement();
            };
      final _AccessContext context = await _context(
        repository: premiumRepository,
        activationRepository: activationRepository,
        waitForAccess: false,
      );
      addTearDown(context.dispose);
      await _waitFor(() => activationRepository.calls == 1);

      context.auth.emit(null);
      await Future<void>.delayed(Duration.zero);
      activationBarrier.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final AsyncValue<InvestmentPremiumAccessState> value = context.container
          .read(investmentPremiumAccessControllerProvider);
      expect(value.value?.canMutateManual ?? false, isFalse);
      expect(premiumRepository.refreshCalls, 1);
    },
  );

  test(
    'sucesso da callable sem entitlement server-side não libera acesso',
    () async {
      final FakePremiumEntitlementRepository premiumRepository =
          FakePremiumEntitlementRepository();
      final FakeClosedTestActivationRepository activationRepository =
          FakeClosedTestActivationRepository();
      final _AccessContext context = await _context(
        repository: premiumRepository,
        activationRepository: activationRepository,
      );
      addTearDown(context.dispose);

      expect(activationRepository.calls, 1);
      expect(premiumRepository.refreshCalls, 2);
      expect(
        context.state.status,
        InvestmentPremiumAccessStatus.confirmationError,
      );
      expect(context.state.canReadManual, isFalse);
    },
  );

  test('múltiplos retries durante ativação não repetem a callable', () async {
    final Completer<void> activationBarrier = Completer<void>();
    final FakePremiumEntitlementRepository premiumRepository =
        FakePremiumEntitlementRepository();
    final FakeClosedTestActivationRepository activationRepository =
        FakeClosedTestActivationRepository()
          ..barrier = activationBarrier
          ..onActivate = () {
            premiumRepository.entitlement = syntheticPremiumEntitlement();
          };
    final _AccessContext context = await _context(
      repository: premiumRepository,
      activationRepository: activationRepository,
      waitForAccess: false,
    );
    addTearDown(context.dispose);
    await _waitFor(() => activationRepository.calls == 1);

    final InvestmentPremiumAccessController controller = context.container.read(
      investmentPremiumAccessControllerProvider.notifier,
    );
    await Future.wait(<Future<void>>[controller.retry(), controller.retry()]);
    activationBarrier.complete();
    await _waitFor(
      () =>
          context.container
              .read(investmentPremiumAccessControllerProvider)
              .value
              ?.status ==
          InvestmentPremiumAccessStatus.full,
    );

    expect(activationRepository.calls, 1);
  });

  test('production nunca tenta ativação automática', () async {
    final FakeClosedTestActivationRepository activationRepository =
        FakeClosedTestActivationRepository();
    final _AccessContext context = await _context(
      environment: AppEnvironment.production,
      activationRepository: activationRepository,
    );
    addTearDown(context.dispose);

    expect(activationRepository.calls, 0);
    expect(context.state.status, InvestmentPremiumAccessStatus.denied);
    expect(context.state.problem, InvestmentPremiumAccessProblem.missing);
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
  FakeClosedTestActivationRepository? activationRepository,
  AppEnvironment environment = AppEnvironment.development,
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
      appEnvironmentProvider.overrideWithValue(environment),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      premiumEntitlementRepositoryProvider.overrideWithValue(premiumRepository),
      closedTestActivationRepositoryProvider.overrideWithValue(
        activationRepository ?? FakeClosedTestActivationRepository(),
      ),
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

Future<void> _waitFor(bool Function() predicate) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Synthetic condition was not reached.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
