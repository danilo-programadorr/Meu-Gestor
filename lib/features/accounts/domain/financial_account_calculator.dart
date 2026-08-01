import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';

abstract final class FinancialAccountCalculator {
  static Money totalOpeningBalance(Iterable<FinancialAccount> accounts) {
    int totalCents = 0;
    for (final FinancialAccount account in accounts) {
      if (!account.isArchived && account.includeInTotal) {
        totalCents += account.openingBalanceCents;
      }
    }
    return Money.fromCents(totalCents);
  }
}
