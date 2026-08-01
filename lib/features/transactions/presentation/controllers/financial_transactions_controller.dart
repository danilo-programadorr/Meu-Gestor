import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_repository.dart';

final AsyncNotifierProvider<
  FinancialTransactionsController,
  FinancialTransactionsState
>
financialTransactionsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      FinancialTransactionsController,
      FinancialTransactionsState
    >(FinancialTransactionsController.new);

final financialTransactionDetailsProvider = FutureProvider.autoDispose
    .family<FinancialTransaction, String>((
      Ref ref,
      String transactionId,
    ) async {
      final String ownerId = requireFinancialTransactionOwner(ref);
      return ref
          .read(financialTransactionRepositoryProvider)
          .readOwnTransaction(
            ownerId: ownerId,
            transactionId: transactionId,
            serverOnly: true,
          );
    });

final financialSummaryProvider =
    Provider.autoDispose<AsyncValue<FinancialSummary>>((Ref ref) {
      final AsyncValue<FinancialAccountsState> accounts = ref.watch(
        financialAccountsControllerProvider,
      );
      final AsyncValue<FinancialTransactionsState> transactions = ref.watch(
        financialTransactionsControllerProvider,
      );
      return _combineFinancialSummary(
        accounts: accounts,
        transactions: transactions,
        now: ref.watch(financialClockProvider)(),
      );
    });

final financialWorkspaceProvider =
    Provider.autoDispose<AsyncValue<FinancialWorkspace>>((Ref ref) {
      final AsyncValue<FinancialAccountsState> accounts = ref.watch(
        financialAccountsControllerProvider,
      );
      final AsyncValue<FinancialCategoriesState> categories = ref.watch(
        financialCategoriesControllerProvider,
      );
      final AsyncValue<FinancialTransactionsState> transactions = ref.watch(
        financialTransactionsControllerProvider,
      );
      final AsyncValue<FinancialSummary> summary = _combineFinancialSummary(
        accounts: accounts,
        transactions: transactions,
        now: ref.watch(financialClockProvider)(),
      );
      if (accounts.hasError) {
        return AsyncError<FinancialWorkspace>(
          accounts.error!,
          accounts.stackTrace!,
        );
      }
      if (categories.hasError) {
        return AsyncError<FinancialWorkspace>(
          categories.error!,
          categories.stackTrace!,
        );
      }
      if (transactions.hasError) {
        return AsyncError<FinancialWorkspace>(
          transactions.error!,
          transactions.stackTrace!,
        );
      }
      if (summary.hasError) {
        return AsyncError<FinancialWorkspace>(
          summary.error!,
          summary.stackTrace!,
        );
      }
      if (!accounts.hasValue ||
          !categories.hasValue ||
          !transactions.hasValue ||
          !summary.hasValue) {
        return const AsyncLoading<FinancialWorkspace>();
      }
      return AsyncData<FinancialWorkspace>(
        FinancialWorkspace(
          accounts: accounts.requireValue,
          categories: categories.requireValue,
          transactions: transactions.requireValue,
          summary: summary.requireValue,
        ),
      );
    });

AsyncValue<FinancialSummary> _combineFinancialSummary({
  required AsyncValue<FinancialAccountsState> accounts,
  required AsyncValue<FinancialTransactionsState> transactions,
  required DateTime now,
}) {
  if (accounts.hasError) {
    return AsyncError<FinancialSummary>(accounts.error!, accounts.stackTrace!);
  }
  if (transactions.hasError) {
    return AsyncError<FinancialSummary>(
      transactions.error!,
      transactions.stackTrace!,
    );
  }
  if (!accounts.hasValue || !transactions.hasValue) {
    return const AsyncLoading<FinancialSummary>();
  }
  try {
    return AsyncData<FinancialSummary>(
      AccountBalanceCalculator.calculate(
        accounts: accounts.requireValue.accounts,
        transactions: transactions.requireValue.transactions,
        now: now,
      ),
    );
  } on Object catch (error, stackTrace) {
    return AsyncError<FinancialSummary>(error, stackTrace);
  }
}

final class FinancialWorkspace {
  const FinancialWorkspace({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.summary,
  });

  final FinancialAccountsState accounts;
  final FinancialCategoriesState categories;
  final FinancialTransactionsState transactions;
  final FinancialSummary summary;
}

final class FinancialTransactionsState {
  const FinancialTransactionsState({
    required this.transactions,
    required this.isServerConfirmed,
  });

  final List<FinancialTransaction> transactions;
  final bool isServerConfirmed;

  FinancialTransaction? findById(String transactionId) {
    for (final FinancialTransaction transaction in transactions) {
      if (transaction.id == transactionId) {
        return transaction;
      }
    }
    return null;
  }

  List<FinancialTransaction> filter({
    FinancialTransactionKind? kind,
    String? accountId,
    String? categoryId,
    required bool currentMonthOnly,
    required DateTime now,
  }) => transactions
      .where((FinancialTransaction transaction) {
        if (kind != null && transaction.kind != kind) {
          return false;
        }
        if (accountId != null && transaction.accountId != accountId) {
          return false;
        }
        if (categoryId != null && transaction.categoryId != categoryId) {
          return false;
        }
        return !currentMonthOnly ||
            FinancialTransactionDate.isInMonth(transaction.occurredAt, now);
      })
      .toList(growable: false);
}

final class FinancialTransactionsController
    extends AsyncNotifier<FinancialTransactionsState> {
  @override
  Future<FinancialTransactionsState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<FinancialTransactionsState>();
    state = await AsyncValue.guard<FinancialTransactionsState>(_load);
  }

  void acceptConfirmed(FinancialTransaction transaction) {
    final FinancialTransactionsState? current = state.value;
    if (current == null) {
      return;
    }
    final List<FinancialTransaction> transactions =
        List<FinancialTransaction>.of(current.transactions);
    final int index = transactions.indexWhere(
      (FinancialTransaction item) => item.id == transaction.id,
    );
    if (index < 0) {
      transactions.add(transaction);
    } else {
      transactions[index] = transaction;
    }
    transactions.sort(
      (FinancialTransaction first, FinancialTransaction second) =>
          second.occurredAt.compareTo(first.occurredAt),
    );
    state = AsyncData<FinancialTransactionsState>(
      FinancialTransactionsState(
        transactions: List<FinancialTransaction>.unmodifiable(transactions),
        isServerConfirmed: true,
      ),
    );
  }

  Future<FinancialTransactionsState> _load() async {
    final String ownerId = requireFinancialTransactionOwner(ref);
    final FinancialTransactionsReadResult result = await ref
        .read(financialTransactionRepositoryProvider)
        .readOwnTransactions(ownerId: ownerId, serverOnly: true);
    if (!result.isFromServer || result.hasPendingWrites) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.failedPrecondition,
        safeMessage:
            'Não foi possível confirmar seus lançamentos com o servidor. Tente novamente.',
        code: 'transactions_server_confirmation_required',
      );
    }
    return FinancialTransactionsState(
      transactions: result.transactions,
      isServerConfirmed: true,
    );
  }
}

String requireFinancialTransactionOwner(Ref ref) {
  final String? ownerId = verifiedFinancialOwner(ref);
  if (ownerId == null) {
    throw const FinancialTransactionFailure(
      kind: FinancialTransactionFailureKind.unauthenticated,
      safeMessage:
          'Confirme seu acesso e seu perfil antes de consultar lançamentos.',
      code: 'transaction_access_gate_denied',
    );
  }
  return ownerId;
}
