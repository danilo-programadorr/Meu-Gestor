import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';

void main() {
  final DateTime augustClock = DateTime.utc(2026, 8, 15, 15);

  test('1. receita ativa do mês atual aparece em receitas', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(amountCents: 12345),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 12345);
  });

  test('2. despesa ativa do mês atual aparece em despesas', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(
        kind: FinancialTransactionKind.expense,
        amountCents: 2345,
      ),
    ], augustClock);
    expect(summary.currentMonth.expense.cents, 2345);
  });

  test('3. receitas, despesas e resultado usam centavos exatos', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(amountCents: 12345),
      createTestTransaction(
        id: 'expense',
        kind: FinancialTransactionKind.expense,
        amountCents: 2345,
      ),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 12345);
    expect(summary.currentMonth.expense.cents, 2345);
    expect(summary.currentMonth.difference.cents, 10000);
  });

  test('4. lançamento cancelado não participa', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(isVoided: true),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 0);
    expect(summary.totalCurrentBalance.cents, 0);
  });

  test('5. lançamento do mês anterior não participa do resumo', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(occurredAt: DateTime.utc(2026, 7, 31, 3)),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 0);
  });

  test('6. primeiro dia civil do mês participa', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(occurredAt: DateTime.utc(2026, 8, 1, 3)),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 250000);
  });

  test('7. último instante civil do mês participa', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(
        occurredAt: DateTime.utc(2026, 9, 1, 2, 59, 59, 999, 999),
      ),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 250000);
  });

  test('8. primeiro dia civil do mês seguinte não participa', () {
    final FinancialSummary summary = _summary(<FinancialTransaction>[
      createTestTransaction(occurredAt: DateTime.utc(2026, 9, 1, 3)),
    ], augustClock);
    expect(summary.currentMonth.income.cents, 0);
  });

  test('9. filtros visuais não alteram o resumo mensal', () {
    final List<FinancialTransaction> transactions = <FinancialTransaction>[
      createTestTransaction(amountCents: 12345),
      createTestTransaction(
        id: 'expense',
        categoryId: 'expense-category',
        kind: FinancialTransactionKind.expense,
        amountCents: 2345,
      ),
    ];
    final FinancialTransactionsState visualState = FinancialTransactionsState(
      transactions: transactions,
      isServerConfirmed: true,
    );
    expect(
      visualState.filter(
        kind: FinancialTransactionKind.income,
        currentMonthOnly: true,
        now: augustClock,
      ),
      hasLength(1),
    );
    final FinancialSummary summary = _summary(transactions, augustClock);
    expect(summary.currentMonth.income.cents, 12345);
    expect(summary.currentMonth.expense.cents, 2345);
  });

  test('13. conversão UTC preserva o dia civil de São Paulo', () {
    expect(
      FinancialTransactionDate.saoPauloCalendarDate(
        DateTime.utc(2026, 8, 1, 2, 59, 59),
      ),
      DateTime.utc(2026, 7, 31),
    );
    expect(
      FinancialTransactionDate.saoPauloCalendarDate(
        DateTime.utc(2026, 8, 1, 3),
      ),
      DateTime.utc(2026, 8, 1),
    );
  });

  test('intervalo mensal é inclusivo no início e exclusivo no fim', () {
    final FinancialMonthInterval interval =
        FinancialMonthInterval.fromReference(augustClock);
    expect(interval.start, DateTime.utc(2026, 8));
    expect(interval.end, DateTime.utc(2026, 9));
    expect(interval.contains(DateTime.utc(2026, 8, 1, 3)), isTrue);
    expect(interval.contains(DateTime.utc(2026, 9, 1, 3)), isFalse);
  });
}

FinancialSummary _summary(
  List<FinancialTransaction> transactions,
  DateTime now,
) => AccountBalanceCalculator.calculate(
  accounts: <FinancialAccount>[createTestAccount(openingBalanceCents: 0)],
  transactions: transactions,
  now: now,
);
