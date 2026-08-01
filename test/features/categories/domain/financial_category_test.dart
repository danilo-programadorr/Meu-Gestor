import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';

import '../../../support/financial_category_fixtures.dart';

void main() {
  group('FinancialCategoryName', () {
    test('normaliza espaços externos e repetidos', () {
      expect(
        FinancialCategoryName.requireValid('  Renda   extra  '),
        'Renda extra',
      );
    });

    for (final String invalid in <String>[
      '',
      'A',
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'Nome\nruim',
    ]) {
      test('rejeita nome inválido ${invalid.length}', () {
        expect(
          () => FinancialCategoryName.requireValid(invalid),
          throwsException,
        );
      });
    }
  });

  test('catálogos persistidos têm tamanhos e chaves fechados', () {
    expect(FinancialCategoryKind.values.map((value) => value.name), <String>[
      'income',
      'expense',
    ]);
    expect(FinancialCategoryIcon.values, hasLength(14));
    expect(FinancialCategoryColor.values, hasLength(10));
    expect(
      () => FinancialCategoryIcon.fromStorage('unknown'),
      throwsFormatException,
    );
    expect(
      () => FinancialCategoryColor.fromStorage('unknown'),
      throwsFormatException,
    );
  });

  group('FinancialCategory', () {
    test('aceita modelo ativo e arquivado coerentes', () {
      expect(
        () => FinancialCategory.validate(createTestCategory()),
        returnsNormally,
      );
      expect(
        () => FinancialCategory.validate(createTestCategory(isArchived: true)),
        returnsNormally,
      );
    });

    test('rejeita estado de arquivamento incoerente', () {
      final FinancialCategory invalid = createTestCategory().copyWith(
        archivedAt: DateTime.utc(2026, 8, 1),
      );
      expect(() => FinancialCategory.validate(invalid), throwsFormatException);
    });

    test('copyWith não permite mudar tipo nem identidade', () {
      final FinancialCategory source = createTestCategory();
      final FinancialCategory edited = source.copyWith(name: 'Nova renda');
      expect(edited.kind, source.kind);
      expect(edited.id, source.id);
      expect(edited.ownerId, source.ownerId);
    });
  });
}
