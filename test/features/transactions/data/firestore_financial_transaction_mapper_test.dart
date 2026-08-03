import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/firestore_financial_transaction_mapper.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

void main() {
  final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
  final DateTime now = DateTime.utc(2026, 8, 2, 12);
  Map<String, dynamic> validMap() => <String, dynamic>{
    'ownerId': 'owner',
    'accountId': 'account-1',
    'categoryId': 'category-1',
    'kind': 'income',
    'description': 'Salário mensal',
    'amountCents': 250000,
    'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1, 3)),
    'notes': '',
    'isVoided': false,
    'voidedAt': null,
    'createdAt': Timestamp.fromDate(timestamp),
    'updatedAt': Timestamp.fromDate(timestamp),
    'schemaVersion': 1,
  };

  test('converte documento estrito', () {
    final FinancialTransaction transaction =
        FirestoreFinancialTransactionMapper.fromMap(
          data: validMap(),
          documentId: 'transaction-1',
          expectedOwnerId: 'owner',
          now: now,
        );
    expect(transaction.amountCents, 250000);
    expect(transaction.kind, FinancialTransactionKind.income);
  });

  for (final String mutation in <String>[
    'missing',
    'extra',
    'owner',
    'double',
    'future',
    'timestamp',
  ]) {
    test('rejeita documento incompatível: $mutation', () {
      final Map<String, dynamic> data = validMap();
      switch (mutation) {
        case 'missing':
          data.remove('notes');
          break;
        case 'extra':
          data['balance'] = 1;
          break;
        case 'owner':
          data['ownerId'] = 'other';
          break;
        case 'double':
          data['amountCents'] = 1.5;
          break;
        case 'future':
          data['occurredAt'] = Timestamp.fromDate(DateTime.utc(2026, 8, 3, 3));
          break;
        case 'timestamp':
          data['updatedAt'] = null;
          break;
      }
      expect(
        () => FirestoreFinancialTransactionMapper.fromMap(
          data: data,
          documentId: 'transaction-1',
          expectedOwnerId: 'owner',
          now: now,
        ),
        throwsA(isA<FinancialTransactionFailure>()),
      );
    });
  }

  test(
    'mapa de criação usa campos exatos, inteiro e timestamps do servidor',
    () {
      final Map<String, Object?> data =
          FirestoreFinancialTransactionMapper.creationMap(
            ownerId: 'owner',
            draft: FinancialTransactionDraft(
              accountId: 'account-1',
              categoryId: 'category-1',
              kind: FinancialTransactionKind.income,
              description: '  Renda  extra ',
              amountCents: 12345,
              occurredAt: DateTime.utc(2026, 8, 1, 3),
              notes: ' nota ',
            ),
            now: now,
          );
      expect(data.keys.toSet(), FirestoreFinancialTransactionMapper.fieldNames);
      expect(data['amountCents'], isA<int>());
      expect(data['description'], 'Renda extra');
      expect(data['createdAt'], isA<FieldValue>());
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data['schemaVersion'], 2);
      expect(data['originType'], 'manual');
      expect(data['originId'], isNull);
    },
  );

  test('converte esquema 2 vinculado e preserva esquema 1 manual', () {
    final Map<String, dynamic> linked = validMap()
      ..['schemaVersion'] = 2
      ..['originType'] = 'payable'
      ..['originId'] = 'payable-1';
    final FinancialTransaction transaction =
        FirestoreFinancialTransactionMapper.fromMap(
          data: linked,
          documentId: 'transaction-1',
          expectedOwnerId: 'owner',
          now: now,
        );

    expect(transaction.originType, FinancialTransactionOriginType.payable);
    expect(transaction.originId, 'payable-1');
    expect(
      FirestoreFinancialTransactionMapper.fromMap(
        data: validMap(),
        documentId: 'legacy-1',
        expectedOwnerId: 'owner',
        now: now,
      ).originType,
      FinancialTransactionOriginType.manual,
    );
  });

  test('rejeita campos de origem incompatíveis com a versão', () {
    final Map<String, dynamic> legacyWithOrigin = validMap()
      ..['originType'] = 'manual'
      ..['originId'] = null;
    final Map<String, dynamic> linkedWithoutOrigin = validMap()
      ..['schemaVersion'] = 2
      ..['originType'] = 'payable'
      ..['originId'] = null;

    expect(
      () => FirestoreFinancialTransactionMapper.fromMap(
        data: legacyWithOrigin,
        documentId: 'legacy-1',
        expectedOwnerId: 'owner',
        now: now,
      ),
      throwsA(isA<FinancialTransactionFailure>()),
    );
    expect(
      () => FirestoreFinancialTransactionMapper.fromMap(
        data: linkedWithoutOrigin,
        documentId: 'linked-1',
        expectedOwnerId: 'owner',
        now: now,
      ),
      throwsA(isA<FinancialTransactionFailure>()),
    );
  });

  test('edição não permite conta, tipo nem valor', () {
    final Map<String, Object> data =
        FirestoreFinancialTransactionMapper.editableMap(
          edit: FinancialTransactionEdit(
            categoryId: 'category-2',
            description: 'Descrição ajustada',
            occurredAt: DateTime.utc(2026, 8, 1, 3),
            notes: '',
          ),
          now: now,
        );
    expect(data.keys, <String>[
      'categoryId',
      'description',
      'occurredAt',
      'notes',
      'updatedAt',
    ]);
    expect(data, isNot(contains('accountId')));
    expect(data, isNot(contains('amountCents')));
    expect(data, isNot(contains('kind')));
  });
}
