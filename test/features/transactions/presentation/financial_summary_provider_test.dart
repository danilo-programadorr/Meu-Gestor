import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transaction_action_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('10. criar lançamento recompõe o resumo confirmado', () async {
    final _SummaryContext context = await _createContext();
    addTearDown(context.dispose);

    await context.action.create(
      FinancialTransactionDraft(
        accountId: 'account-1',
        categoryId: 'category-1',
        kind: FinancialTransactionKind.income,
        description: 'Receita confirmada',
        amountCents: 12345,
        occurredAt: DateTime.utc(2026, 8, 5, 3),
        notes: '',
      ),
    );

    expect(context.summary.currentMonth.income.cents, 12345);
    expect(context.summary.totalCurrentBalance.cents, 112345);
  });

  test('11. cancelar lançamento recompõe resumo e saldo', () async {
    final _SummaryContext context = await _createContext(
      transactions: <FinancialTransaction>[
        createTestTransaction(amountCents: 12345),
      ],
    );
    addTearDown(context.dispose);
    expect(context.summary.currentMonth.income.cents, 12345);

    await context.action.voidTransaction(transactionId: 'transaction-1');

    expect(context.summary.currentMonth.income.cents, 0);
    expect(context.summary.totalCurrentBalance.cents, 100000);
    expect(context.repository.transactions.single.isVoided, isTrue);
  });

  test('12. mover data recompõe o mês de origem e o de destino', () async {
    DateTime currentClock = DateTime.utc(2026, 8, 15, 15);
    final _SummaryContext context = await _createContext(
      transactions: <FinancialTransaction>[createTestTransaction()],
      clock: () => currentClock,
    );
    addTearDown(context.dispose);
    expect(context.summary.currentMonth.income.cents, 250000);

    await context.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Receita movida',
        occurredAt: DateTime.utc(2026, 7, 31, 3),
        notes: '',
      ),
    );
    expect(context.summary.currentMonth.income.cents, 0);

    currentClock = DateTime.utc(2026, 7, 15, 15);
    context.container.invalidate(financialSummaryProvider);
    expect(context.summary.currentMonth.income.cents, 250000);
  });

  test(
    '14. relógio injetado torna o resumo independente da data real',
    () async {
      final _SummaryContext august = await _createContext(
        transactions: <FinancialTransaction>[createTestTransaction()],
        clock: () => DateTime.utc(2026, 8, 15, 15),
      );
      addTearDown(august.dispose);
      final _SummaryContext september = await _createContext(
        transactions: <FinancialTransaction>[createTestTransaction()],
        clock: () => DateTime.utc(2026, 9, 15, 15),
      );
      addTearDown(september.dispose);

      expect(august.summary.currentMonth.income.cents, 250000);
      expect(september.summary.currentMonth.income.cents, 0);
    },
  );
}

final class _SummaryContext {
  const _SummaryContext({
    required this.container,
    required this.auth,
    required this.repository,
    required this.gateSubscription,
    required this.accountsSubscription,
    required this.transactionsSubscription,
    required this.actionSubscription,
    required this.summarySubscription,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeFinancialTransactionRepository repository;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gateSubscription;
  final ProviderSubscription<AsyncValue<FinancialAccountsState>>
  accountsSubscription;
  final ProviderSubscription<AsyncValue<FinancialTransactionsState>>
  transactionsSubscription;
  final ProviderSubscription<FinancialTransactionActionState>
  actionSubscription;
  final ProviderSubscription<AsyncValue<FinancialSummary>> summarySubscription;

  FinancialTransactionActionController get action =>
      container.read(financialTransactionActionControllerProvider.notifier);

  FinancialSummary get summary => summarySubscription.read().requireValue;

  void dispose() {
    summarySubscription.close();
    actionSubscription.close();
    transactionsSubscription.close();
    accountsSubscription.close();
    gateSubscription.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_SummaryContext> _createContext({
  List<FinancialTransaction>? transactions,
  DateTime Function()? clock,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialTransactionRepository transactionsRepository =
      FakeFinancialTransactionRepository(initialTransactions: transactions);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      financialAccountRepositoryProvider.overrideWithValue(
        FakeFinancialAccountRepository(
          initialAccounts: <FinancialAccount>[createTestAccount()],
        ),
      ),
      financialTransactionRepositoryProvider.overrideWithValue(
        transactionsRepository,
      ),
      financialClockProvider.overrideWithValue(
        clock ?? () => DateTime.utc(2026, 8, 15, 15),
      ),
    ],
  );
  final Completer<void> profileReady = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gateSubscription =
      container.listen(profileGateControllerProvider, (
        AsyncValue<ProfileGateState>? previous,
        AsyncValue<ProfileGateState> next,
      ) {
        if (next.value?.isTerminal == true && !profileReady.isCompleted) {
          profileReady.complete();
        }
      }, fireImmediately: true);
  await profileReady.future.timeout(const Duration(seconds: 2));

  final ProviderSubscription<AsyncValue<FinancialAccountsState>>
  accountsSubscription = container.listen(
    financialAccountsControllerProvider,
    (_, _) {},
  );
  final ProviderSubscription<AsyncValue<FinancialTransactionsState>>
  transactionsSubscription = container.listen(
    financialTransactionsControllerProvider,
    (_, _) {},
  );
  final ProviderSubscription<FinancialTransactionActionState>
  actionSubscription = container.listen(
    financialTransactionActionControllerProvider,
    (_, _) {},
  );
  final ProviderSubscription<AsyncValue<FinancialSummary>> summarySubscription =
      container.listen(financialSummaryProvider, (_, _) {});
  await Future.wait<void>(<Future<void>>[
    container.read(financialAccountsControllerProvider.future).then((_) {}),
    container.read(financialTransactionsControllerProvider.future).then((_) {}),
  ]);
  return _SummaryContext(
    container: container,
    auth: auth,
    repository: transactionsRepository,
    gateSubscription: gateSubscription,
    accountsSubscription: accountsSubscription,
    transactionsSubscription: transactionsSubscription,
    actionSubscription: actionSubscription,
    summarySubscription: summarySubscription,
  );
}
