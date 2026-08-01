import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

final class AccountCurrentBalance {
  const AccountCurrentBalance({
    required this.account,
    required this.currentBalance,
  });

  final FinancialAccount account;
  final Money currentBalance;
}

final class MonthlyFinancialSummary {
  const MonthlyFinancialSummary({required this.income, required this.expense});

  final Money income;
  final Money expense;

  Money get difference => income - expense;
}

final class FinancialSummary {
  const FinancialSummary({
    required this.accountBalances,
    required this.totalCurrentBalance,
    required this.currentMonth,
  });

  final List<AccountCurrentBalance> accountBalances;
  final Money totalCurrentBalance;
  final MonthlyFinancialSummary currentMonth;

  Money balanceForAccount(String accountId) {
    for (final AccountCurrentBalance balance in accountBalances) {
      if (balance.account.id == accountId) {
        return balance.currentBalance;
      }
    }
    throw const FinancialTransactionFailure(
      kind: FinancialTransactionFailureKind.notFound,
      safeMessage: 'Esta conta não foi encontrada.',
      code: 'balance_account_not_found',
    );
  }
}

abstract final class AccountBalanceCalculator {
  static FinancialSummary calculate({
    required Iterable<FinancialAccount> accounts,
    required Iterable<FinancialTransaction> transactions,
    required DateTime now,
  }) {
    final Map<String, BigInt> movementByAccount = <String, BigInt>{};
    BigInt monthIncome = BigInt.zero;
    BigInt monthExpense = BigInt.zero;
    for (final FinancialTransaction transaction in transactions) {
      if (transaction.isVoided) {
        continue;
      }
      final BigInt amount = BigInt.from(transaction.amountCents);
      final BigInt signed = transaction.kind == FinancialTransactionKind.income
          ? amount
          : -amount;
      movementByAccount.update(
        transaction.accountId,
        (BigInt current) => current + signed,
        ifAbsent: () => signed,
      );
      if (FinancialTransactionDate.isInMonth(transaction.occurredAt, now)) {
        if (transaction.kind == FinancialTransactionKind.income) {
          monthIncome += amount;
        } else {
          monthExpense += amount;
        }
      }
    }

    final List<AccountCurrentBalance> balances = <AccountCurrentBalance>[];
    BigInt total = BigInt.zero;
    for (final FinancialAccount account in accounts) {
      final BigInt current =
          BigInt.from(account.openingBalanceCents) +
          (movementByAccount[account.id] ?? BigInt.zero);
      final int currentCents = _checkedInt(current);
      balances.add(
        AccountCurrentBalance(
          account: account,
          currentBalance: Money.fromCents(currentCents),
        ),
      );
      if (!account.isArchived && account.includeInTotal) {
        total += current;
      }
    }
    return FinancialSummary(
      accountBalances: List<AccountCurrentBalance>.unmodifiable(balances),
      totalCurrentBalance: Money.fromCents(_checkedInt(total)),
      currentMonth: MonthlyFinancialSummary(
        income: Money.fromCents(_checkedInt(monthIncome)),
        expense: Money.fromCents(_checkedInt(monthExpense)),
      ),
    );
  }

  static int _checkedInt(BigInt value) {
    final BigInt minimum = BigInt.parse('-9223372036854775808');
    final BigInt maximum = BigInt.parse('9223372036854775807');
    if (value < minimum || value > maximum) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.overflow,
        safeMessage:
            'O total ultrapassou o limite seguro de cálculo. Nenhum dado foi alterado.',
        code: 'financial_balance_overflow',
      );
    }
    return value.toInt();
  }
}
