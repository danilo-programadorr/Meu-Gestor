import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_text.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/positive_money_input_parser.dart';

import '../../../support/financial_transaction_fixtures.dart';

void main() {
  group('PositiveMoneyInputParser', () {
    final Map<String, int> accepted = <String, int>{
      '0,01': 1,
      '1': 100,
      'R\$ 1.234,5': 123450,
      '99.999.999,99': 9999999999,
    };
    for (final MapEntry<String, int> entry in accepted.entries) {
      test('converte ${entry.key} somente para centavos inteiros', () {
        expect(PositiveMoneyInputParser.parseBrlCents(entry.key), entry.value);
      });
    }
    for (final String invalid in <String>[
      '0',
      '0,00',
      '-1',
      '1.2',
      '1,234',
      '100.000.000,00',
    ]) {
      test('rejeita entrada monetária $invalid', () {
        expect(
          () => PositiveMoneyInputParser.parseBrlCents(invalid),
          throwsA(isA<FinancialTransactionFailure>()),
        );
      });
    }
    test('formata centavos para edição em pt-BR', () {
      expect(PositiveMoneyInputParser.formatEditable(123456), '1.234,56');
    });
  });

  group('texto', () {
    test('normaliza descrição e observações', () {
      expect(
        FinancialTransactionText.requireDescription('  Venda   avulsa '),
        'Venda avulsa',
      );
      expect(
        FinancialTransactionText.requireNotes(' observação '),
        'observação',
      );
    });
    test('rejeita limites e caracteres de controle', () {
      expect(
        () => FinancialTransactionText.requireDescription('A'),
        throwsException,
      );
      expect(
        () => FinancialTransactionText.requireDescription('A\nB'),
        throwsException,
      );
      expect(
        () => FinancialTransactionText.requireNotes(
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        ),
        throwsException,
      );
    });
  });

  group('datas America/Sao_Paulo', () {
    test('preserva a data civil na convenção de 03:00 UTC', () {
      final DateTime stored = FinancialTransactionDate.fromCalendarDate(
        DateTime(2026, 8, 1),
      );
      expect(stored, DateTime.utc(2026, 8, 1, 3));
      expect(
        FinancialTransactionDate.saoPauloCalendarDate(stored),
        DateTime.utc(2026, 8, 1),
      );
    });
    test('não muda o dia antes da meia-noite em São Paulo', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 2, 59);
      expect(
        FinancialTransactionDate.todayInSaoPaulo(now),
        DateTime.utc(2026, 8, 1),
      );
    });
    test('rejeita data futura e aceita hoje', () {
      final DateTime now = DateTime.utc(2026, 8, 2, 12);
      expect(
        () => FinancialTransactionDate.validateNotFuture(
          DateTime.utc(2026, 8, 2, 3),
          now,
        ),
        returnsNormally,
      );
      expect(
        () => FinancialTransactionDate.validateNotFuture(
          DateTime.utc(2026, 8, 3, 3),
          now,
        ),
        throwsA(isA<FinancialTransactionFailure>()),
      );
    });
  });

  group('FinancialTransaction', () {
    test(
      'receita é positiva e despesa é negativa sem alterar o valor persistido',
      () {
        expect(createTestTransaction().signedAmountCents, 250000);
        expect(
          createTestTransaction(
            kind: FinancialTransactionKind.expense,
          ).signedAmountCents,
          -250000,
        );
      },
    );
    test('rejeita zero, negativo e acima do limite', () {
      for (final int cents in <int>[0, -1, 10000000000]) {
        expect(
          () => FinancialTransaction.validateAmount(cents),
          throwsException,
        );
      }
    });
    test('cancelamento exige timestamp coerente', () {
      final FinancialTransaction invalid = createTestTransaction().copyWith(
        isVoided: true,
      );
      expect(
        () => FinancialTransaction.validate(
          invalid,
          now: DateTime.utc(2026, 8, 2),
        ),
        throwsA(isA<FinancialTransactionFailure>()),
      );
    });
    test('aceita origem vinculada somente no esquema 2', () {
      expect(
        () => FinancialTransaction.validate(
          createTestTransaction(),
          now: DateTime.utc(2026, 8, 2),
        ),
        returnsNormally,
      );
      final FinancialTransaction linked = FinancialTransaction(
        id: 'transaction-2',
        ownerId: 'owner',
        accountId: 'account-1',
        categoryId: 'category-1',
        kind: FinancialTransactionKind.expense,
        description: 'Conta de luz',
        amountCents: 10000,
        occurredAt: DateTime.utc(2026, 8, 1, 3),
        notes: '',
        isVoided: false,
        voidedAt: null,
        createdAt: DateTime.utc(2026, 8, 1, 12),
        updatedAt: DateTime.utc(2026, 8, 1, 12),
        schemaVersion: FinancialTransaction.linkedSchemaVersion,
        originType: FinancialTransactionOriginType.payable,
        originId: 'payable-1',
      );

      expect(
        () => FinancialTransaction.validate(
          linked,
          now: DateTime.utc(2026, 8, 2),
        ),
        returnsNormally,
      );
      expect(
        () => FinancialTransaction.validate(
          FinancialTransaction(
            id: linked.id,
            ownerId: linked.ownerId,
            accountId: linked.accountId,
            categoryId: linked.categoryId,
            kind: linked.kind,
            description: linked.description,
            amountCents: linked.amountCents,
            occurredAt: linked.occurredAt,
            notes: linked.notes,
            isVoided: linked.isVoided,
            voidedAt: linked.voidedAt,
            createdAt: linked.createdAt,
            updatedAt: linked.updatedAt,
            schemaVersion: FinancialTransaction.currentSchemaVersion,
            originType: FinancialTransactionOriginType.payable,
            originId: 'payable-1',
          ),
          now: DateTime.utc(2026, 8, 2),
        ),
        throwsA(isA<FinancialTransactionFailure>()),
      );
    });
  });
}
