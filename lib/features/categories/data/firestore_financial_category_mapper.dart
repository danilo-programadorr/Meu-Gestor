import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';

abstract final class FirestoreFinancialCategoryMapper {
  static const Set<String> fieldNames = <String>{
    'ownerId',
    'name',
    'kind',
    'iconKey',
    'colorKey',
    'isArchived',
    'archivedAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  static FinancialCategory fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
  }) {
    try {
      final Set<String> actualFields = data.keys.toSet();
      if (actualFields.difference(fieldNames).isNotEmpty ||
          fieldNames.difference(actualFields).isNotEmpty) {
        throw _incompatible('unexpected_category_fields');
      }
      final String ownerId = _string(data, 'ownerId');
      final String name = _string(data, 'name');
      final bool isArchived = _boolean(data, 'isArchived');
      final DateTime? archivedAt = _nullableDateTime(data, 'archivedAt');
      final FinancialCategory category = FinancialCategory(
        id: documentId,
        ownerId: ownerId,
        name: name,
        kind: FinancialCategoryKind.fromStorage(_string(data, 'kind')),
        icon: FinancialCategoryIcon.fromStorage(_string(data, 'iconKey')),
        color: FinancialCategoryColor.fromStorage(_string(data, 'colorKey')),
        isArchived: isArchived,
        archivedAt: archivedAt,
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: _integer(data, 'schemaVersion'),
      );
      if (ownerId != expectedOwnerId ||
          FinancialCategoryName.normalize(name) != name) {
        throw _incompatible('invalid_category_invariant');
      }
      FinancialCategory.validate(category);
      return category;
    } on FinancialCategoryFailure {
      rethrow;
    } on Object {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.conversion,
        safeMessage:
            'Encontramos uma inconsistência nesta categoria. Nenhum dado foi alterado.',
        code: 'category_conversion_failed',
      );
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required FinancialCategoryDraft draft,
  }) {
    final FinancialCategoryDraft normalized = draft.normalized();
    return <String, Object?>{
      'ownerId': ownerId,
      'name': normalized.name,
      'kind': normalized.kind.name,
      'iconKey': normalized.icon.name,
      'colorKey': normalized.color.name,
      'isArchived': false,
      'archivedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': FinancialCategory.currentSchemaVersion,
    };
  }

  static Map<String, Object> editableMap(FinancialCategoryDraft draft) {
    final FinancialCategoryDraft normalized = draft.normalized();
    return <String, Object>{
      'name': normalized.name,
      'iconKey': normalized.icon.name,
      'colorKey': normalized.color.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static bool matchesDraft(
    FinancialCategory category,
    FinancialCategoryDraft draft,
  ) {
    final FinancialCategoryDraft normalized = draft.normalized();
    return category.name == normalized.name &&
        category.kind == normalized.kind &&
        category.icon == normalized.icon &&
        category.color == normalized.color;
  }

  static bool _boolean(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! bool) {
      throw StateError('invalid_boolean');
    }
    return value;
  }

  static DateTime _dateTime(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! Timestamp) {
      throw StateError('invalid_or_pending_timestamp');
    }
    return value.toDate().toUtc();
  }

  static DateTime? _nullableDateTime(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) {
      return null;
    }
    if (value is! Timestamp) {
      throw StateError('invalid_timestamp');
    }
    return value.toDate().toUtc();
  }

  static int _integer(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! int) {
      throw StateError('invalid_integer');
    }
    return value;
  }

  static String _string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) {
      throw StateError('invalid_string');
    }
    return value;
  }

  static FinancialCategoryFailure _incompatible(
    String code,
  ) => FinancialCategoryFailure(
    kind: FinancialCategoryFailureKind.incompatible,
    safeMessage:
        'Encontramos uma inconsistência nesta categoria. Nenhum dado foi alterado.',
    code: code,
  );
}
