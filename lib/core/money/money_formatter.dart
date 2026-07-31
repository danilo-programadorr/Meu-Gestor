import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';

abstract final class MoneyFormatter {
  static final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern(
    'pt_BR',
  );

  static String format(Money money) {
    final int absoluteCents = money.cents.abs();
    final int wholeUnits = absoluteCents ~/ 100;
    final int fractionalUnits = absoluteCents.remainder(100);
    final String sign = money.cents < 0 ? '-' : '';
    final String wholePart = _wholeNumberFormat.format(wholeUnits);
    final String fractionalPart = fractionalUnits.toString().padLeft(2, '0');

    return '$sign${money.currency.symbol} $wholePart,$fractionalPart';
  }
}
