import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

void main() {
  group('valores escalados de investimentos', () {
    test('interpreta e formata quantidade pt-BR sem ponto flutuante', () {
      final InvestmentQuantity value = InvestmentQuantity.parsePtBr(
        '1.234,56789012',
      );
      expect(value.scaled, 123456789012);
      expect(value.formatPtBr(), '1.234,56789012');
    });

    test('aceita preço com seis casas e preserva duas na exibição', () {
      final InvestmentUnitPrice value = InvestmentUnitPrice.parsePtBr('32,5');
      expect(value.scaled, 32500000);
      expect(value.formatPtBr(), '32,50');
    });

    test('rejeita zero, sinal, formato estrangeiro e precisão excedente', () {
      for (final String input in <String>[
        '0',
        '-1',
        '1.23',
        '1,123456789',
        '1 000',
      ]) {
        expect(
          () => InvestmentQuantity.parsePtBr(input),
          throwsA(isA<InvestmentFailure>()),
          reason: input,
        );
      }
    });

    test('converte taxas em centavos inteiros', () {
      expect(InvestmentMoneyInput.parseNonNegativeCents(''), 0);
      expect(InvestmentMoneyInput.parseNonNegativeCents(r'R$ 1.234,5'), 123450);
      expect(InvestmentMoneyInput.formatEditable(123450), '1.234,50');
    });

    test('calcula valor bruto com BigInt e arredondamento half-up', () {
      expect(
        InvestmentArithmetic.grossAmountCents(
          quantityScaled: 150000000,
          unitPriceScaled: 1000005,
        ),
        150,
      );
      expect(
        InvestmentArithmetic.roundHalfUp(BigInt.from(5), BigInt.from(2)),
        BigInt.from(3),
      );
      expect(
        InvestmentArithmetic.roundHalfUp(BigInt.from(-5), BigInt.from(2)),
        BigInt.from(-3),
      );
    });

    test('aceita os extremos int64 e rejeita estouro', () {
      expect(
        InvestmentArithmetic.checkedInt64(
          BigInt.from(InvestmentScale.maximumInt64),
        ),
        InvestmentScale.maximumInt64,
      );
      expect(
        InvestmentArithmetic.checkedInt64(
          BigInt.from(InvestmentScale.minimumInt64),
        ),
        InvestmentScale.minimumInt64,
      );
      expect(
        () => InvestmentArithmetic.checkedInt64(
          BigInt.from(InvestmentScale.maximumInt64) + BigInt.one,
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('mantém dinheiro, quantidade, preço e resultado como inteiros', () {
      expect(InvestmentQuantity.parsePtBr('1,5').scaled, isA<int>());
      expect(InvestmentUnitPrice.parsePtBr('10,25').scaled, isA<int>());
      expect(InvestmentMoneyInput.parseNonNegativeCents('1,25'), isA<int>());
      expect(
        InvestmentArithmetic.grossAmountCents(
          quantityScaled: 150000000,
          unitPriceScaled: 10250000,
        ),
        isA<int>(),
      );
    });
  });
}
