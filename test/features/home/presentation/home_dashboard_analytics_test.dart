import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_analytics.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_filter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_category_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 15,
  );

  test('filtro mensal usa data civil e ignora anulados', () {
    final FinancialWorkspace workspace = _workspace();
    final HomeDashboardAnalytics analytics = HomeDashboardAnalytics.calculate(
      workspace: workspace,
      filter: HomeDashboardFilter.currentMonth(today),
    );

    expect(analytics.income.cents, 250000);
    expect(analytics.expense.cents, 50000);
    expect(analytics.result.cents, 200000);
    expect(analytics.transactions.map((item) => item.id), <String>[
      'expense-august',
      'income-august',
    ]);
    expect(analytics.categoryExpenses.single.label, 'Moradia');
    expect(analytics.categoryExpenses.single.fraction, 1);
  });

  test('filtro de conta atualiza saldo e indicadores sem mudar a fonte', () {
    final FinancialWorkspace workspace = _workspace();
    final HomeDashboardFilter filter = HomeDashboardFilter.currentMonth(
      today,
    ).withAccount('account-2');
    final HomeDashboardAnalytics analytics = HomeDashboardAnalytics.calculate(
      workspace: workspace,
      filter: filter,
    );

    expect(analytics.balance.cents, 150000);
    expect(analytics.income.cents, 0);
    expect(analytics.expense.cents, 50000);
    expect(analytics.transactions.single.id, 'expense-august');
    expect(workspace.transactions.transactions, hasLength(4));
  });

  test('presets calculam mês, ano e período inclusivo', () {
    final HomeDashboardFilter previous = HomeDashboardFilter.forPreset(
      DashboardPeriodPreset.previousMonth,
      SaoPauloCivilDate(year: 2026, month: 1, day: 10),
    );
    expect(previous.start.toString(), '2025-12-01');
    expect(previous.end.toString(), '2025-12-31');

    final HomeDashboardFilter year = HomeDashboardFilter.forPreset(
      DashboardPeriodPreset.currentYear,
      today,
    );
    expect(year.start.toString(), '2026-01-01');
    expect(year.end.toString(), '2026-12-31');

    final HomeDashboardFilter custom = HomeDashboardFilter.custom(
      start: SaoPauloCivilDate(year: 2026, month: 8, day: 5),
      end: SaoPauloCivilDate(year: 2026, month: 8, day: 5),
    );
    expect(
      custom.includes(SaoPauloCivilDate(year: 2026, month: 8, day: 5)),
      isTrue,
    );
  });

  test('mês e ano cria intervalo civil completo e rótulo localizado', () {
    final HomeDashboardFilter selected = HomeDashboardFilter.monthAndYear(
      year: 2024,
      month: 2,
      accountId: 'account-1',
    );

    expect(selected.start.toString(), '2024-02-01');
    expect(selected.end.toString(), '2024-02-29');
    expect(selected.periodLabel, 'Fevereiro 2024');
    expect(selected.accountId, 'account-1');
    expect(selected.isDefaultFor(today), isFalse);
    expect(HomeDashboardFilter.currentMonth(today).isDefaultFor(today), isTrue);
  });
}

FinancialWorkspace _workspace() {
  final List<FinancialAccount> accounts = <FinancialAccount>[
    createTestAccount(),
    createTestAccount(
      id: 'account-2',
      name: 'Carteira',
      openingBalanceCents: 200000,
      type: FinancialAccountType.digitalWallet,
    ),
  ];
  final List<FinancialCategory> categories = <FinancialCategory>[
    createTestCategory(),
    createTestCategory(
      id: 'expense-category',
      name: 'Moradia',
      kind: FinancialCategoryKind.expense,
      icon: FinancialCategoryIcon.home,
      color: FinancialCategoryColor.blue,
    ),
  ];
  final List<FinancialTransaction> transactions = <FinancialTransaction>[
    createTestTransaction(id: 'income-august'),
    createTestTransaction(
      id: 'expense-august',
      accountId: 'account-2',
      categoryId: 'expense-category',
      kind: FinancialTransactionKind.expense,
      amountCents: 50000,
      occurredAt: DateTime.utc(2026, 8, 5, 3),
    ),
    createTestTransaction(
      id: 'income-july',
      amountCents: 10000,
      occurredAt: DateTime.utc(2026, 7, 31, 2, 59),
    ),
    createTestTransaction(
      id: 'voided-august',
      amountCents: 90000,
      occurredAt: DateTime.utc(2026, 8, 7, 3),
      isVoided: true,
    ),
  ];
  return FinancialWorkspace(
    accounts: FinancialAccountsState(
      accounts: accounts,
      isServerConfirmed: true,
    ),
    categories: FinancialCategoriesState(
      categories: categories,
      isServerConfirmed: true,
    ),
    transactions: FinancialTransactionsState(
      transactions: transactions,
      isServerConfirmed: true,
    ),
    summary: AccountBalanceCalculator.calculate(
      accounts: accounts,
      transactions: transactions,
      now: DateTime.utc(2026, 8, 15, 15),
    ),
  );
}
