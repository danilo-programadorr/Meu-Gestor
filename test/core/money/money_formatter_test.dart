import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';

void main() {
  group('MoneyFormatter', () {
    test('formata valor positivo em pt-BR sem ponto flutuante', () {
      const Money value = Money.fromCents(123456);

      expect(MoneyFormatter.format(value), r'R$ 1.234,56');
    });

    test('formata zero com duas casas decimais', () {
      expect(MoneyFormatter.format(const Money.fromCents(0)), r'R$ 0,00');
    });

    test('formata valor negativo com sinal antes da moeda', () {
      expect(MoneyFormatter.format(const Money.fromCents(-75)), r'-R$ 0,75');
    });
  });
}
