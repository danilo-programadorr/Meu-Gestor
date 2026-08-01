import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';

import '../../../support/financial_account_fixtures.dart';

void main() {
  group('FinancialAccountType', () {
    test('possui somente os seis tipos autorizados', () {
      expect(
        FinancialAccountType.values.map(
          (FinancialAccountType type) => type.name,
        ),
        <String>[
          'checking',
          'savings',
          'cash',
          'digitalWallet',
          'investment',
          'other',
        ],
      );
    });

    test('converte tipo persistido conhecido', () {
      expect(
        FinancialAccountType.fromStorage('investment'),
        FinancialAccountType.investment,
      );
    });

    test('rejeita tipo persistido desconhecido', () {
      expect(
        () => FinancialAccountType.fromStorage('creditCard'),
        throwsFormatException,
      );
    });
  });

  group('FinancialAccount', () {
    test('modelo válido preserva saldo em centavos', () {
      final FinancialAccount account = createTestAccount(
        openingBalanceCents: -123456,
      );
      FinancialAccount.validate(account);
      expect(account.openingBalance.cents, -123456);
    });

    for (final int cents in <int>[
      FinancialAccount.minimumOpeningBalanceCents,
      -1,
      0,
      1,
      FinancialAccount.maximumOpeningBalanceCents,
    ]) {
      test('aceita saldo autorizado $cents', () {
        expect(
          () => FinancialAccount.validateOpeningBalance(cents),
          returnsNormally,
        );
      });
    }

    test('rejeita saldo abaixo e acima do limite', () {
      expect(
        () => FinancialAccount.validateOpeningBalance(-10000000000),
        throwsFormatException,
      );
      expect(
        () => FinancialAccount.validateOpeningBalance(10000000000),
        throwsFormatException,
      );
    });

    test('rejeita moeda diferente de BRL', () {
      final FinancialAccount source = createTestAccount();
      final FinancialAccount invalid = FinancialAccount(
        id: source.id,
        ownerId: source.ownerId,
        name: source.name,
        type: source.type,
        openingBalanceCents: source.openingBalanceCents,
        currencyCode: 'USD',
        includeInTotal: source.includeInTotal,
        isArchived: source.isArchived,
        archivedAt: source.archivedAt,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        schemaVersion: source.schemaVersion,
      );
      expect(() => FinancialAccount.validate(invalid), throwsFormatException);
    });

    test('rejeita schemaVersion incompatível', () {
      final FinancialAccount source = createTestAccount();
      final FinancialAccount invalid = FinancialAccount(
        id: source.id,
        ownerId: source.ownerId,
        name: source.name,
        type: source.type,
        openingBalanceCents: source.openingBalanceCents,
        currencyCode: source.currencyCode,
        includeInTotal: source.includeInTotal,
        isArchived: source.isArchived,
        archivedAt: source.archivedAt,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        schemaVersion: 2,
      );
      expect(() => FinancialAccount.validate(invalid), throwsFormatException);
    });

    test('rejeita archivedAt incoerente com estado ativo', () {
      final FinancialAccount source = createTestAccount();
      final FinancialAccount invalid = source.copyWith(
        archivedAt: DateTime.utc(2026, 8, 1),
      );
      expect(() => FinancialAccount.validate(invalid), throwsFormatException);
    });

    test('conta arquivada possui archivedAt coerente', () {
      expect(
        () => FinancialAccount.validate(createTestAccount(isArchived: true)),
        returnsNormally,
      );
    });
  });
}
