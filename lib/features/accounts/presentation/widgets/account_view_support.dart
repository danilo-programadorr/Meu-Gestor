import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';

IconData accountTypeIcon(FinancialAccountType type) => switch (type) {
  FinancialAccountType.checking => Icons.account_balance_outlined,
  FinancialAccountType.savings => Icons.savings_outlined,
  FinancialAccountType.cash => Icons.account_balance_wallet_outlined,
  FinancialAccountType.digitalWallet => Icons.wallet_outlined,
  FinancialAccountType.investment => Icons.trending_up_rounded,
  FinancialAccountType.other => Icons.payments_outlined,
};

String safeAccountsErrorMessage(Object error) {
  if (error is FinancialAccountFailure) {
    return switch (error.kind) {
      FinancialAccountFailureKind.permissionDenied =>
        'Não foi possível acessar suas contas com segurança.',
      FinancialAccountFailureKind.unavailable ||
      FinancialAccountFailureKind.timeout ||
      FinancialAccountFailureKind.aborted =>
        'Verifique sua conexão e tente novamente.',
      FinancialAccountFailureKind.conversion ||
      FinancialAccountFailureKind.incompatible ||
      FinancialAccountFailureKind.dataLoss =>
        'Encontramos uma inconsistência em uma conta. Nenhum dado foi alterado.',
      _ => error.safeMessage,
    };
  }
  return 'Não foi possível carregar suas contas. Tente novamente.';
}
