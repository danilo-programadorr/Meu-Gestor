import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/categories/data/firestore_financial_category_mapper.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';

void main() {
  final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);

  Map<String, dynamic> validMap() => <String, dynamic>{
    'ownerId': 'owner',
    'name': 'Salário',
    'kind': 'income',
    'iconKey': 'salary',
    'colorKey': 'green',
    'isArchived': false,
    'archivedAt': null,
    'createdAt': Timestamp.fromDate(timestamp),
    'updatedAt': Timestamp.fromDate(timestamp),
    'schemaVersion': 1,
  };

  test('converte documento com campos exatos', () {
    final FinancialCategory category = FirestoreFinancialCategoryMapper.fromMap(
      data: validMap(),
      documentId: 'category-1',
      expectedOwnerId: 'owner',
    );
    expect(category.name, 'Salário');
    expect(category.kind, FinancialCategoryKind.income);
  });

  for (final String mutation in <String>[
    'missing',
    'extra',
    'owner',
    'pendingTimestamp',
  ]) {
    test('rejeita documento incompatível: $mutation', () {
      final Map<String, dynamic> data = validMap();
      switch (mutation) {
        case 'missing':
          data.remove('iconKey');
          break;
        case 'extra':
          data['unexpected'] = true;
          break;
        case 'owner':
          data['ownerId'] = 'other';
          break;
        case 'pendingTimestamp':
          data['updatedAt'] = null;
          break;
      }
      expect(
        () => FirestoreFinancialCategoryMapper.fromMap(
          data: data,
          documentId: 'category-1',
          expectedOwnerId: 'owner',
        ),
        throwsA(isA<FinancialCategoryFailure>()),
      );
    });
  }

  test('mapa de criação usa somente o contrato e timestamps do servidor', () {
    final Map<String, Object?> data =
        FirestoreFinancialCategoryMapper.creationMap(
          ownerId: 'owner',
          draft: const FinancialCategoryDraft(
            name: '  Renda  extra ',
            kind: FinancialCategoryKind.income,
            icon: FinancialCategoryIcon.extraIncome,
            color: FinancialCategoryColor.cyan,
          ),
        );
    expect(data.keys.toSet(), FirestoreFinancialCategoryMapper.fieldNames);
    expect(data['name'], 'Renda extra');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['updatedAt'], isA<FieldValue>());
  });
}
