import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/money_input_parser.dart';

void main() {
  group('MoneyInputParser', () {
    final Map<String, int> validCases = <String, int>{
      '0': 0,
      '0,00': 0,
      '1': 100,
      '1,2': 120,
      '1,23': 123,
      '1.234,56': 123456,
      '1234,56': 123456,
      r'R$ 1.234,56': 123456,
      '-1.234,56': -123456,
      '-0,01': -1,
      '99.999.999,99': 9999999999,
      '-99.999.999,99': -9999999999,
    };
    for (final MapEntry<String, int> entry in validCases.entries) {
      test('converte ${entry.key} para ${entry.value} centavos', () {
        expect(MoneyInputParser.parseBrlCents(entry.key), entry.value);
      });
    }

    for (final String value in <String>[
      '',
      '-',
      'abc',
      '1.23',
      '1,234',
      '1..000,00',
      '1.00,00',
      '100.000.000,00',
      '-100.000.000,00',
    ]) {
      test('rejeita entrada inválida $value', () {
        expect(
          () => MoneyInputParser.parseBrlCents(value),
          throwsA(isA<FinancialAccountFailure>()),
        );
      });
    }

    test('formata centavos sem usar ponto flutuante', () {
      expect(MoneyInputParser.formatEditable(123456), '1.234,56');
      expect(MoneyInputParser.formatEditable(-1), '-0,01');
      expect(MoneyInputParser.formatEditable(0), '0,00');
    });
  });
}
