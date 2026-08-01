import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

IconData transactionKindIcon(FinancialTransactionKind kind) => switch (kind) {
  FinancialTransactionKind.income => Icons.arrow_downward_rounded,
  FinancialTransactionKind.expense => Icons.arrow_upward_rounded,
};

String formatFinancialDate(DateTime instant) => DateFormat(
  'dd/MM/yyyy',
  'pt_BR',
).format(FinancialTransactionDate.saoPauloCalendarDate(instant));

String safeTransactionsErrorMessage(Object error) {
  if (error is FinancialTransactionFailure) {
    return switch (error.kind) {
      FinancialTransactionFailureKind.permissionDenied =>
        'Não foi possível acessar seus lançamentos com segurança.',
      FinancialTransactionFailureKind.unavailable ||
      FinancialTransactionFailureKind.timeout ||
      FinancialTransactionFailureKind.aborted ||
      FinancialTransactionFailureKind.uncertain =>
        'Verifique sua conexão e tente novamente.',
      FinancialTransactionFailureKind.conversion ||
      FinancialTransactionFailureKind.incompatible ||
      FinancialTransactionFailureKind.dataLoss =>
        'Encontramos uma inconsistência em um lançamento. Nenhum dado foi alterado.',
      _ => error.safeMessage,
    };
  }
  return 'Não foi possível carregar seus lançamentos. Tente novamente.';
}
