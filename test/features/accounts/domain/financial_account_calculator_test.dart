import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_calculator.dart';

import '../../../support/financial_account_fixtures.dart';

void main() {
  group('FinancialAccountCalculator', () {
    test('lista vazia totaliza zero', () {
      expect(
        FinancialAccountCalculator.totalOpeningBalance(<Never>[]).cents,
        0,
      );
    });

    test('soma positivos, negativos e zero em centavos', () {
      final int total =
          FinancialAccountCalculator.totalOpeningBalance(<FinancialAccount>[
            createTestAccount(id: '1', openingBalanceCents: 10000),
            createTestAccount(id: '2', openingBalanceCents: -2500),
            createTestAccount(id: '3', openingBalanceCents: 0),
          ]).cents;
      expect(total, 7500);
    });

    test('ignora conta excluída do total', () {
      expect(
        FinancialAccountCalculator.totalOpeningBalance(<FinancialAccount>[
          createTestAccount(includeInTotal: false),
        ]).cents,
        0,
      );
    });

    test('ignora conta arquivada', () {
      expect(
        FinancialAccountCalculator.totalOpeningBalance(<FinancialAccount>[
          createTestAccount(isArchived: true),
        ]).cents,
        0,
      );
    });

    test('soma valores próximos ao limite sem double', () {
      expect(
        FinancialAccountCalculator.totalOpeningBalance(<FinancialAccount>[
          createTestAccount(id: '1', openingBalanceCents: 9999999999),
          createTestAccount(id: '2', openingBalanceCents: 9999999999),
        ]).cents,
        19999999998,
      );
    });
  });
}
