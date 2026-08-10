import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';

abstract final class InvestmentScale {
  static const int quantityDigits = 8;
  static const int priceDigits = 6;
  static const int quantityFactor = 100000000;
  static const int priceFactor = 1000000;
  static const int moneyConversionDivisor = 1000000000000;
  static const int maximumQuantityScaled = 999999999999999;
  static const int maximumUnitPriceScaled = 999999999999;
  static const int maximumFeesCents = 9999999999;
  static const int maximumMoneyCents = maximumFeesCents;
  static const int minimumInt64 = -9223372036854775808;
  static const int maximumInt64 = 9223372036854775807;
}

final class InvestmentQuantity implements Comparable<InvestmentQuantity> {
  InvestmentQuantity.fromScaled(this.scaled) {
    if (scaled <= 0 || scaled > InvestmentScale.maximumQuantityScaled) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe uma quantidade maior que zero.',
        code: 'investment_quantity_out_of_range',
      );
    }
  }

  factory InvestmentQuantity.parsePtBr(String input) =>
      InvestmentQuantity.fromScaled(
        ScaledInvestmentInput.parsePositive(
          input,
          scaleDigits: InvestmentScale.quantityDigits,
          maximumScaled: InvestmentScale.maximumQuantityScaled,
          safeMessage: 'Informe uma quantidade válida maior que zero.',
        ),
      );

  final int scaled;

  String formatPtBr() => ScaledInvestmentInput.formatPtBr(
    scaled,
    scaleDigits: InvestmentScale.quantityDigits,
  );

  @override
  int compareTo(InvestmentQuantity other) => scaled.compareTo(other.scaled);
}

final class InvestmentUnitPrice {
  InvestmentUnitPrice.fromScaled(this.scaled) {
    if (scaled <= 0 || scaled > InvestmentScale.maximumUnitPriceScaled) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe um preço por unidade maior que zero.',
        code: 'investment_unit_price_out_of_range',
      );
    }
  }

  factory InvestmentUnitPrice.parsePtBr(String input) =>
      InvestmentUnitPrice.fromScaled(
        ScaledInvestmentInput.parsePositive(
          input,
          scaleDigits: InvestmentScale.priceDigits,
          maximumScaled: InvestmentScale.maximumUnitPriceScaled,
          safeMessage: 'Informe um preço por unidade válido.',
        ),
      );

  final int scaled;

  String formatPtBr() => ScaledInvestmentInput.formatPtBr(
    scaled,
    scaleDigits: InvestmentScale.priceDigits,
    minimumFractionDigits: 2,
  );
}

abstract final class InvestmentArithmetic {
  static int grossAmountCents({
    required int quantityScaled,
    required int unitPriceScaled,
  }) {
    final BigInt numerator =
        BigInt.from(quantityScaled) * BigInt.from(unitPriceScaled);
    return checkedInt64(
      roundHalfUp(
        numerator,
        BigInt.from(InvestmentScale.moneyConversionDivisor),
      ),
    );
  }

  static int averageUnitPriceScaled({
    required int costCents,
    required int quantityScaled,
  }) {
    if (costCents <= 0 || quantityScaled <= 0) {
      return 0;
    }
    final BigInt numerator =
        BigInt.from(costCents) *
        BigInt.from(InvestmentScale.moneyConversionDivisor);
    return checkedInt64(roundHalfUp(numerator, BigInt.from(quantityScaled)));
  }

  static BigInt roundHalfUp(BigInt numerator, BigInt denominator) {
    if (denominator <= BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator');
    }
    final bool negative = numerator.isNegative;
    final BigInt absolute = numerator.abs();
    final BigInt rounded =
        (absolute + (denominator ~/ BigInt.two)) ~/ denominator;
    return negative ? -rounded : rounded;
  }

  static int checkedInt64(BigInt value) {
    if (value < BigInt.from(InvestmentScale.minimumInt64) ||
        value > BigInt.from(InvestmentScale.maximumInt64)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.overflow,
        safeMessage:
            'O cálculo ultrapassou o limite seguro. Nenhum dado foi alterado.',
        code: 'investment_int64_overflow',
      );
    }
    return value.toInt();
  }
}

abstract final class ScaledInvestmentInput {
  static int parsePositive(
    String input, {
    required int scaleDigits,
    required int maximumScaled,
    required String safeMessage,
  }) {
    final String value = input.trim();
    final RegExp pattern = RegExp(
      '^(?:(?:\\d{1,3}(?:\\.\\d{3})+)|\\d+)(?:,\\d{1,$scaleDigits})?\$',
    );
    if (!pattern.hasMatch(value)) {
      throw InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: safeMessage,
        code: 'invalid_scaled_investment_input',
      );
    }
    final List<String> parts = value.split(',');
    final String whole = parts.first.replaceAll('.', '');
    final String fraction = parts.length == 1
        ? ''.padRight(scaleDigits, '0')
        : parts.last.padRight(scaleDigits, '0');
    final BigInt parsed = BigInt.parse('$whole$fraction');
    if (parsed <= BigInt.zero || parsed > BigInt.from(maximumScaled)) {
      throw InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: safeMessage,
        code: 'scaled_investment_input_out_of_range',
      );
    }
    return parsed.toInt();
  }

  static String formatPtBr(
    int scaled, {
    required int scaleDigits,
    int minimumFractionDigits = 0,
  }) {
    final int factor = _powerOfTen(scaleDigits);
    final int absolute = scaled.abs();
    final int whole = absolute ~/ factor;
    String fraction = absolute
        .remainder(factor)
        .toString()
        .padLeft(scaleDigits, '0');
    while (fraction.length > minimumFractionDigits && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    final String grouped = NumberFormat.decimalPattern('pt_BR').format(whole);
    return '${scaled < 0 ? '-' : ''}$grouped${fraction.isEmpty ? '' : ',$fraction'}';
  }

  static int _powerOfTen(int exponent) {
    int result = 1;
    for (int index = 0; index < exponent; index += 1) {
      result *= 10;
    }
    return result;
  }
}

abstract final class InvestmentMoneyInput {
  static int parseNonNegativeCents(String input) {
    String value = input.trim();
    if (value.isEmpty) {
      return 0;
    }
    if (value.startsWith(r'R$')) {
      value = value.substring(2).trim();
    }
    final RegExp pattern = RegExp(
      r'^(?:(?:\d{1,3}(?:\.\d{3})+)|\d+)(?:,\d{1,2})?$',
    );
    if (!pattern.hasMatch(value)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe um valor válido em reais e centavos.',
        code: 'invalid_investment_money_input',
      );
    }
    final List<String> parts = value.split(',');
    final String whole = parts.first.replaceAll('.', '');
    final String fraction = parts.length == 1
        ? '00'
        : parts.last.padRight(2, '0');
    final BigInt cents = BigInt.parse('$whole$fraction');
    if (cents > BigInt.from(InvestmentScale.maximumFeesCents)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'O valor informado ultrapassa o limite permitido.',
        code: 'investment_money_input_out_of_range',
      );
    }
    return cents.toInt();
  }

  static String formatEditable(int cents) {
    if (cents < 0 || cents > InvestmentScale.maximumFeesCents) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'O valor informado não é válido.',
        code: 'invalid_investment_money_value',
      );
    }
    final String whole = (cents ~/ 100).toString();
    final StringBuffer grouped = StringBuffer();
    for (int index = 0; index < whole.length; index += 1) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(whole[index]);
    }
    return '$grouped,${cents.remainder(100).toString().padLeft(2, '0')}';
  }
}
