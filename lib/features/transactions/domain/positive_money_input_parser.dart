import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

abstract final class PositiveMoneyInputParser {
  static int parseBrlCents(String input) {
    String value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.startsWith(r'R$')) {
      value = value.substring(2).trim();
    }
    final RegExp pattern = RegExp(
      r'^(?:(?:\d{1,3}(?:\.\d{3})+)|\d+)(?:,\d{1,2})?$',
    );
    if (!pattern.hasMatch(value)) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.invalidAmount,
        safeMessage: 'Informe um valor válido em reais e centavos.',
        code: 'invalid_transaction_amount_input',
      );
    }
    final List<String> parts = value.split(',');
    final String wholeDigits = parts.first.replaceAll('.', '');
    final String fractionalDigits = parts.length == 1
        ? '00'
        : parts.last.padRight(2, '0');
    final int cents = int.parse('$wholeDigits$fractionalDigits');
    FinancialTransaction.validateAmount(cents);
    return cents;
  }

  static String formatEditable(int cents) {
    FinancialTransaction.validateAmount(cents);
    final String whole = (cents ~/ 100).toString();
    final StringBuffer grouped = StringBuffer();
    for (int index = 0; index < whole.length; index += 1) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(whole[index]);
    }
    final String fraction = cents.remainder(100).toString().padLeft(2, '0');
    return '$grouped,$fraction';
  }
}
