import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/core/money/currency.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';

void main() {
  group('Money', () {
    test('armazena o valor em centavos inteiros', () {
      const Money value = Money.fromCents(12345);

      expect(value.cents, 12345);
      expect(value.currency, Currency.brl);
    });

    test('soma valores da mesma moeda', () {
      const Money first = Money.fromCents(1050);
      const Money second = Money.fromCents(250);

      expect(first + second, const Money.fromCents(1300));
    });

    test('subtrai valores da mesma moeda', () {
      const Money first = Money.fromCents(1050);
      const Money second = Money.fromCents(250);

      expect(first - second, const Money.fromCents(800));
    });

    test('rejeita ponto flutuante como unidade monetária', () {
      expect(
        () => Money.fromMinorUnits(10.5),
        throwsA(isA<InvalidMoneyException>()),
      );
    });

    test('aceita BRL sem diferenciar maiúsculas e espaços', () {
      expect(Currency.fromCode(' brl '), Currency.brl);
    });

    test('rejeita moeda diferente de BRL', () {
      expect(
        () => Currency.fromCode('USD'),
        throwsA(isA<InvalidCurrencyException>()),
      );
    });
  });
}
