import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_account_action_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('carrega somente lista confirmada pelo servidor', () async {
    final _AccountsContext context = await _context(
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);
    final ProviderSubscription<AsyncValue<FinancialAccountsState>>
    subscription = context.container.listen(
      financialAccountsControllerProvider,
      (
        AsyncValue<FinancialAccountsState>? previous,
        AsyncValue<FinancialAccountsState> next,
      ) {},
    );
    addTearDown(subscription.close);

    final FinancialAccountsState state = await context.container.read(
      financialAccountsControllerProvider.future,
    );

    expect(state.accounts, hasLength(1));
    expect(state.isServerConfirmed, isTrue);
    expect(context.repository.readCalls, 1);
  });

  test(
    'mantém estado de carregamento enquanto leitura está pendente',
    () async {
      final _AccountsContext context = await _context();
      addTearDown(context.dispose);
      final Completer<void> barrier = Completer<void>();
      context.repository.readBarrier = barrier;

      final ProviderSubscription<AsyncValue<FinancialAccountsState>>
      subscription = context.container.listen(
        financialAccountsControllerProvider,
        (
          AsyncValue<FinancialAccountsState>? previous,
          AsyncValue<FinancialAccountsState> next,
        ) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      expect(
        context.container.read(financialAccountsControllerProvider).isLoading,
        isTrue,
      );
      barrier.complete();
      await context.container.read(financialAccountsControllerProvider.future);
      expect(
        context.container.read(financialAccountsControllerProvider).hasValue,
        isTrue,
      );
    },
  );

  test('cache ou escrita pendente não libera total', () async {
    final _AccountsContext context = await _context();
    addTearDown(context.dispose);
    context.repository
      ..serverConfirmed = false
      ..pendingWrites = true;
    final Completer<Object> failure = Completer<Object>();
    final ProviderSubscription<AsyncValue<FinancialAccountsState>>
    subscription = context.container
        .listen(financialAccountsControllerProvider, (
          AsyncValue<FinancialAccountsState>? previous,
          AsyncValue<FinancialAccountsState> next,
        ) {
          if (next.error case final Object error when !failure.isCompleted) {
            failure.complete(error);
          }
        });
    addTearDown(subscription.close);

    expect(
      await failure.future.timeout(const Duration(seconds: 2)),
      isA<FinancialAccountFailure>(),
    );
  });

  test('refresh faz nova leitura do servidor', () async {
    final _AccountsContext context = await _context();
    addTearDown(context.dispose);
    final ProviderSubscription<AsyncValue<FinancialAccountsState>>
    subscription = context.container.listen(
      financialAccountsControllerProvider,
      (
        AsyncValue<FinancialAccountsState>? previous,
        AsyncValue<FinancialAccountsState> next,
      ) {},
    );
    addTearDown(subscription.close);
    await context.container.read(financialAccountsControllerProvider.future);

    await context.container
        .read(financialAccountsControllerProvider.notifier)
        .refresh();

    expect(context.repository.readCalls, 2);
  });

  test('criação bloqueia múltiplos toques', () async {
    final _AccountsContext context = await _context();
    addTearDown(context.dispose);
    final Completer<void> barrier = Completer<void>();
    context.repository.mutationBarrier = barrier;
    final FinancialAccountActionController controller = context.container.read(
      financialAccountActionControllerProvider.notifier,
    );
    const FinancialAccountDraft draft = FinancialAccountDraft(
      name: 'Conta principal',
      type: FinancialAccountType.checking,
      openingBalanceCents: 100,
      includeInTotal: true,
    );

    final Future<void> first = controller.create(draft);
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.create(draft);
    barrier.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(context.repository.createCalls, 1);
    expect(context.repository.generatedIdCalls, 1);
    expect(
      context.container.read(financialAccountActionControllerProvider).status,
      FinancialAccountActionStatus.success,
    );
  });

  test('retry incerto reutiliza o mesmo ID e não duplica', () async {
    final _AccountsContext context = await _context();
    addTearDown(context.dispose);
    context.repository.nextFailure = const FinancialAccountFailure(
      kind: FinancialAccountFailureKind.unavailable,
      safeMessage: 'Indisponível.',
    );
    final FinancialAccountActionController controller = context.container.read(
      financialAccountActionControllerProvider.notifier,
    );
    const FinancialAccountDraft draft = FinancialAccountDraft(
      name: 'Conta principal',
      type: FinancialAccountType.checking,
      openingBalanceCents: 100,
      includeInTotal: true,
    );

    await controller.create(draft);
    expect(
      context.container
          .read(financialAccountActionControllerProvider)
          .operationUncertain,
      isTrue,
    );
    await controller.create(draft);

    expect(context.repository.generatedIdCalls, 1);
    expect(context.repository.createCalls, 2);
    expect(context.repository.accounts, hasLength(1));
  });

  test('edita apenas campos autorizados pelo contrato', () async {
    final _AccountsContext context = await _context(
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);
    final FinancialAccountActionController controller = context.container.read(
      financialAccountActionControllerProvider.notifier,
    );

    await controller.updateAccount(
      accountId: 'account-1',
      draft: const FinancialAccountDraft(
        name: 'Poupança da casa',
        type: FinancialAccountType.savings,
        openingBalanceCents: -250,
        includeInTotal: false,
      ),
    );

    final FinancialAccount updated = context.repository.accounts.single;
    expect(updated.name, 'Poupança da casa');
    expect(updated.type, FinancialAccountType.savings);
    expect(updated.openingBalanceCents, -250);
    expect(updated.includeInTotal, isFalse);
    expect(updated.ownerId, 'owner');
  });

  test('arquiva e restaura sem exclusão', () async {
    final _AccountsContext context = await _context(
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);
    final FinancialAccountActionController controller = context.container.read(
      financialAccountActionControllerProvider.notifier,
    );

    await controller.setArchived(accountId: 'account-1', archived: true);
    expect(context.repository.accounts.single.isArchived, isTrue);
    expect(context.repository.accounts.single.archivedAt, isNotNull);

    await controller.setArchived(accountId: 'account-1', archived: false);
    expect(context.repository.accounts.single.isArchived, isFalse);
    expect(context.repository.accounts.single.archivedAt, isNull);
    expect(context.repository.accounts, hasLength(1));
  });

  test('perfil ausente bloqueia criação antes do repositório', () async {
    final _AccountsContext context = await _context(validProfile: false);
    addTearDown(context.dispose);
    await context.container
        .read(financialAccountActionControllerProvider.notifier)
        .create(
          const FinancialAccountDraft(
            name: 'Conta principal',
            type: FinancialAccountType.checking,
            openingBalanceCents: 0,
            includeInTotal: true,
          ),
        );
    expect(context.repository.createCalls, 0);
    expect(
      context.container.read(financialAccountActionControllerProvider).status,
      FinancialAccountActionStatus.failure,
    );
  });

  test('logout durante operação não publica callback de sucesso', () async {
    final _AccountsContext context = await _context();
    addTearDown(context.dispose);
    final Completer<void> barrier = Completer<void>();
    context.repository.mutationBarrier = barrier;
    final Future<void> operation = context.container
        .read(financialAccountActionControllerProvider.notifier)
        .create(
          const FinancialAccountDraft(
            name: 'Conta principal',
            type: FinancialAccountType.checking,
            openingBalanceCents: 0,
            includeInTotal: true,
          ),
        );
    await Future<void>.delayed(Duration.zero);
    context.auth.emit(null);
    barrier.complete();
    await operation;

    expect(
      context.container.read(financialAccountActionControllerProvider).status,
      isNot(FinancialAccountActionStatus.success),
    );
  });
}

final class _AccountsContext {
  const _AccountsContext({
    required this.container,
    required this.auth,
    required this.repository,
    required this.gateSubscription,
    required this.actionSubscription,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeFinancialAccountRepository repository;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gateSubscription;
  final ProviderSubscription<FinancialAccountActionState> actionSubscription;

  void dispose() {
    actionSubscription.close();
    gateSubscription.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_AccountsContext> _context({
  List<FinancialAccount>? accounts,
  bool validProfile = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeUserProfileRepository profiles = FakeUserProfileRepository(
    initialProfile: validProfile ? createTestProfile(ownerId: 'owner') : null,
  );
  final FakeFinancialAccountRepository repository =
      FakeFinancialAccountRepository(initialAccounts: accounts);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(profiles),
      financialAccountRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final Completer<void> gateReady = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gateSubscription =
      container.listen(profileGateControllerProvider, (
        AsyncValue<ProfileGateState>? previous,
        AsyncValue<ProfileGateState> next,
      ) {
        final ProfileGateState? value = next.value;
        if (value != null && value.isTerminal && !gateReady.isCompleted) {
          gateReady.complete();
        }
      }, fireImmediately: true);
  await gateReady.future.timeout(const Duration(seconds: 2));
  final ProviderSubscription<FinancialAccountActionState> actionSubscription =
      container.listen(
        financialAccountActionControllerProvider,
        (
          FinancialAccountActionState? previous,
          FinancialAccountActionState next,
        ) {},
      );
  return _AccountsContext(
    container: container,
    auth: auth,
    repository: repository,
    gateSubscription: gateSubscription,
    actionSubscription: actionSubscription,
  );
}
