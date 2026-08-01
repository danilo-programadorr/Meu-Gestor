import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';

void main() {
  test('saldo atual deriva do inicial mais receitas menos despesas', () {
    final FinancialSummary summary = AccountBalanceCalculator.calculate(
      accounts: <FinancialAccount>[
        createTestAccount(openingBalanceCents: 100000),
      ],
      transactions: <FinancialTransaction>[
        createTestTransaction(amountCents: 50000),
        createTestTransaction(
          id: 'expense',
          kind: FinancialTransactionKind.expense,
          amountCents: 25000,
        ),
      ],
      now: DateTime.utc(2026, 8, 5),
    );
    expect(summary.totalCurrentBalance.cents, 125000);
    expect(summary.currentMonth.income.cents, 50000);
    expect(summary.currentMonth.expense.cents, 25000);
    expect(summary.currentMonth.difference.cents, 25000);
  });

  test('ignora cancelados no saldo e no resumo', () {
    final FinancialSummary summary = AccountBalanceCalculator.calculate(
      accounts: <FinancialAccount>[
        createTestAccount(openingBalanceCents: 100000),
      ],
      transactions: <FinancialTransaction>[
        createTestTransaction(isVoided: true, amountCents: 90000),
      ],
      now: DateTime.utc(2026, 8, 5),
    );
    expect(summary.totalCurrentBalance.cents, 100000);
    expect(summary.currentMonth.income.cents, 0);
  });

  test('conta fora do total mantém saldo próprio sem compor total geral', () {
    final FinancialSummary summary = AccountBalanceCalculator.calculate(
      accounts: <FinancialAccount>[
        createTestAccount(includeInTotal: false, openingBalanceCents: 100000),
      ],
      transactions: const <FinancialTransaction>[],
      now: DateTime.utc(2026, 8, 5),
    );
    expect(summary.balanceForAccount('account-1').cents, 100000);
    expect(summary.totalCurrentBalance.cents, 0);
  });

  test('conta arquivada não compõe o total geral', () {
    final FinancialSummary summary = AccountBalanceCalculator.calculate(
      accounts: <FinancialAccount>[createTestAccount(isArchived: true)],
      transactions: const <FinancialTransaction>[],
      now: DateTime.utc(2026, 8, 5),
    );
    expect(summary.totalCurrentBalance.cents, 0);
  });

  test('lançamento de mês diferente não entra no resumo do mês atual', () {
    final FinancialSummary summary = AccountBalanceCalculator.calculate(
      accounts: <FinancialAccount>[createTestAccount()],
      transactions: <FinancialTransaction>[
        createTestTransaction(occurredAt: DateTime.utc(2026, 7, 31, 3)),
      ],
      now: DateTime.utc(2026, 8, 5),
    );
    expect(summary.currentMonth.income.cents, 0);
  });
}
