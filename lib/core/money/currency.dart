import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';

enum Currency {
  brl(code: 'BRL', symbol: r'R$');

  const Currency({required this.code, required this.symbol});

  factory Currency.fromCode(String code) {
    final String normalizedCode = code.trim().toUpperCase();

    return Currency.values.firstWhere(
      (Currency currency) => currency.code == normalizedCode,
      orElse: () => throw InvalidCurrencyException(
        code: 'unsupported_currency',
        message: 'A moeda $normalizedCode não é aceita nesta versão.',
      ),
    );
  }

  final String code;
  final String symbol;
}
