import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';

abstract final class MoneyInputParser {
  static int parseBrlCents(String input) {
    String value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.startsWith(r'R$')) {
      value = value.substring(2).trim();
    }
    final RegExp pattern = RegExp(
      r'^-?(?:(?:\d{1,3}(?:\.\d{3})+)|\d+)(?:,\d{1,2})?$',
    );
    if (!pattern.hasMatch(value)) {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.validation,
        safeMessage: 'Informe um valor válido em reais e centavos.',
        code: 'invalid_money_input',
      );
    }

    final bool isNegative = value.startsWith('-');
    final String unsigned = isNegative ? value.substring(1) : value;
    final List<String> parts = unsigned.split(',');
    final String wholeDigits = parts.first.replaceAll('.', '');
    final String fractionalDigits = parts.length == 1
        ? '00'
        : parts.last.padRight(2, '0');
    final int absoluteCents = int.parse('$wholeDigits$fractionalDigits');
    final int cents = isNegative ? -absoluteCents : absoluteCents;
    try {
      FinancialAccount.validateOpeningBalance(cents);
    } on FormatException {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.validation,
        safeMessage: 'O saldo inicial está fora do limite permitido.',
        code: 'opening_balance_out_of_range',
      );
    }
    return cents;
  }

  static String formatEditable(int cents) {
    final int absolute = cents.abs();
    final String whole = (absolute ~/ 100).toString();
    final StringBuffer grouped = StringBuffer();
    for (int index = 0; index < whole.length; index += 1) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(whole[index]);
    }
    final String fraction = absolute.remainder(100).toString().padLeft(2, '0');
    return '${cents < 0 ? '-' : ''}$grouped,$fraction';
  }
}
