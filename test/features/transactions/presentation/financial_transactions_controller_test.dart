import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transaction_action_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_transaction_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('filtros locais combinam tipo, conta, categoria e mês', () {
    final FinancialTransactionsState state = FinancialTransactionsState(
      transactions: <FinancialTransaction>[
        createTestTransaction(),
        createTestTransaction(
          id: 'expense',
          accountId: 'account-2',
          categoryId: 'expense-category',
          kind: FinancialTransactionKind.expense,
        ),
        createTestTransaction(
          id: 'old',
          occurredAt: DateTime.utc(2026, 7, 1, 3),
        ),
      ],
      isServerConfirmed: true,
    );
    expect(
      state
          .filter(
            kind: FinancialTransactionKind.income,
            accountId: 'account-1',
            categoryId: 'category-1',
            currentMonthOnly: true,
            now: DateTime.utc(2026, 8, 5),
          )
          .map((item) => item.id),
      <String>['transaction-1'],
    );
  });

  test('lista exige confirmação do servidor', () async {
    final _Context context = await _context(
      serverConfirmed: false,
      awaitList: false,
    );
    addTearDown(context.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(
      context.container.read(financialTransactionsControllerProvider).error,
      isA<FinancialTransactionFailure>(),
    );
  });

  test('múltiplos toques e retry incerto não duplicam lançamento', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final Completer<void> barrier = Completer<void>();
    context.transactions.mutationBarrier = barrier;
    final FinancialTransactionActionController controller = context.container
        .read(financialTransactionActionControllerProvider.notifier);
    final FinancialTransactionDraft draft = FinancialTransactionDraft(
      accountId: 'account-1',
      categoryId: 'category-1',
      kind: FinancialTransactionKind.income,
      description: 'Renda extra',
      amountCents: 100,
      occurredAt: DateTime.utc(2026, 8, 1, 3),
      notes: '',
    );
    final Future<void> first = controller.create(draft);
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.create(draft);
    barrier.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(context.transactions.createCalls, 1);

    context.transactions.nextFailure = const FinancialTransactionFailure(
      kind: FinancialTransactionFailureKind.unavailable,
      safeMessage: 'Indisponível.',
    );
    await controller.create(draft);
    await controller.create(draft);
    expect(context.transactions.generatedIdCalls, 2);
    expect(context.transactions.transactions, hasLength(2));
  });

  test(
    'cancelamento é persistido sem excluir e torna-se idempotente',
    () async {
      final _Context context = await _context(
        transactions: <FinancialTransaction>[createTestTransaction()],
      );
      addTearDown(context.dispose);
      final FinancialTransactionActionController controller = context.container
          .read(financialTransactionActionControllerProvider.notifier);
      await controller.voidTransaction(transactionId: 'transaction-1');
      await controller.voidTransaction(transactionId: 'transaction-1');
      expect(context.transactions.transactions, hasLength(1));
      expect(context.transactions.transactions.single.isVoided, isTrue);
    },
  );
}

final class _Context {
  const _Context({
    required this.container,
    required this.auth,
    required this.transactions,
    required this.gate,
    required this.action,
    required this.list,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeFinancialTransactionRepository transactions;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate;
  final ProviderSubscription<FinancialTransactionActionState> action;
  final ProviderSubscription<AsyncValue<FinancialTransactionsState>> list;

  void dispose() {
    action.close();
    list.close();
    gate.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_Context> _context({
  List<FinancialTransaction>? transactions,
  bool serverConfirmed = true,
  bool awaitList = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialTransactionRepository repository =
      FakeFinancialTransactionRepository(initialTransactions: transactions);
  repository.serverConfirmed = serverConfirmed;
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      financialTransactionRepositoryProvider.overrideWithValue(repository),
      financialClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 5, 12),
      ),
    ],
  );
  final Completer<void> ready = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate = container
      .listen(profileGateControllerProvider, (
        _,
        AsyncValue<ProfileGateState> next,
      ) {
        if (next.value?.isTerminal == true && !ready.isCompleted) {
          ready.complete();
        }
      }, fireImmediately: true);
  await ready.future.timeout(const Duration(seconds: 2));
  final ProviderSubscription<FinancialTransactionActionState> action = container
      .listen(
        financialTransactionActionControllerProvider,
        (
          FinancialTransactionActionState? previous,
          FinancialTransactionActionState next,
        ) {},
      );
  final ProviderSubscription<AsyncValue<FinancialTransactionsState>> list =
      container.listen(
        financialTransactionsControllerProvider,
        (
          AsyncValue<FinancialTransactionsState>? previous,
          AsyncValue<FinancialTransactionsState> next,
        ) {},
      );
  if (awaitList) {
    await container.read(financialTransactionsControllerProvider.future);
  }
  return _Context(
    container: container,
    auth: auth,
    transactions: repository,
    gate: gate,
    action: action,
    list: list,
  );
}
