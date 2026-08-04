import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_filter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

final class DashboardCategoryExpense {
  const DashboardCategoryExpense({
    required this.category,
    required this.amount,
    required this.fraction,
    this.labelOverride,
  });

  final FinancialCategory? category;
  final Money amount;
  final double fraction;
  final String? labelOverride;

  String get label =>
      labelOverride ?? category?.name ?? 'Categoria indisponível';
}

final class HomeDashboardAnalytics {
  const HomeDashboardAnalytics({
    required this.balance,
    required this.income,
    required this.expense,
    required this.transactions,
    required this.categoryExpenses,
  });

  final Money balance;
  final Money income;
  final Money expense;
  final List<FinancialTransaction> transactions;
  final List<DashboardCategoryExpense> categoryExpenses;

  Money get result => income - expense;

  static HomeDashboardAnalytics calculate({
    required FinancialWorkspace workspace,
    required HomeDashboardFilter filter,
  }) {
    final List<FinancialTransaction> transactions =
        workspace.transactions.transactions
            .where((FinancialTransaction transaction) {
              if (transaction.isVoided ||
                  (filter.accountId != null &&
                      transaction.accountId != filter.accountId)) {
                return false;
              }
              return filter.includes(
                SaoPauloCivilDate.fromInstant(transaction.occurredAt.toUtc()),
              );
            })
            .toList(growable: false)
          ..sort(
            (FinancialTransaction first, FinancialTransaction second) =>
                second.occurredAt.compareTo(first.occurredAt),
          );

    int incomeCents = 0;
    int expenseCents = 0;
    final Map<String, int> expensesByCategory = <String, int>{};
    for (final FinancialTransaction transaction in transactions) {
      if (transaction.kind == FinancialTransactionKind.income) {
        incomeCents += transaction.amountCents;
      } else {
        expenseCents += transaction.amountCents;
        expensesByCategory.update(
          transaction.categoryId,
          (int value) => value + transaction.amountCents,
          ifAbsent: () => transaction.amountCents,
        );
      }
    }

    final Map<String, FinancialCategory> categories =
        <String, FinancialCategory>{
          for (final FinancialCategory category
              in workspace.categories.categories)
            category.id: category,
        };
    final List<DashboardCategoryExpense> categoryExpenses =
        expensesByCategory.entries
            .map(
              (MapEntry<String, int> entry) => DashboardCategoryExpense(
                category: categories[entry.key],
                amount: Money.fromCents(entry.value),
                fraction: expenseCents == 0 ? 0 : entry.value / expenseCents,
              ),
            )
            .toList(growable: false)
          ..sort(
            (DashboardCategoryExpense first, DashboardCategoryExpense second) =>
                second.amount.cents.compareTo(first.amount.cents),
          );

    return HomeDashboardAnalytics(
      balance: _selectedBalance(workspace.summary, filter.accountId),
      income: Money.fromCents(incomeCents),
      expense: Money.fromCents(expenseCents),
      transactions: List<FinancialTransaction>.unmodifiable(transactions),
      categoryExpenses: List<DashboardCategoryExpense>.unmodifiable(
        categoryExpenses,
      ),
    );
  }

  static Money _selectedBalance(FinancialSummary summary, String? accountId) =>
      accountId == null
      ? summary.totalCurrentBalance
      : summary.balanceForAccount(accountId);
}
