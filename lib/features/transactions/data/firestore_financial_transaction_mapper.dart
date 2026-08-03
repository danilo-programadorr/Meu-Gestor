import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

abstract final class FirestoreFinancialTransactionMapper {
  static const Set<String> fieldNamesV1 = <String>{
    'ownerId',
    'accountId',
    'categoryId',
    'kind',
    'description',
    'amountCents',
    'occurredAt',
    'notes',
    'isVoided',
    'voidedAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };
  static const Set<String> fieldNamesV2 = <String>{
    ...fieldNamesV1,
    'originType',
    'originId',
  };

  static const Set<String> fieldNames = fieldNamesV2;

  static FinancialTransaction fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
    required DateTime now,
  }) {
    try {
      final int schemaVersion = _integer(data, 'schemaVersion');
      final Set<String> expectedFields = switch (schemaVersion) {
        FinancialTransaction.currentSchemaVersion => fieldNamesV1,
        FinancialTransaction.linkedSchemaVersion => fieldNamesV2,
        _ => throw _incompatible('unsupported_transaction_schema'),
      };
      final Set<String> actualFields = data.keys.toSet();
      if (actualFields.difference(expectedFields).isNotEmpty ||
          expectedFields.difference(actualFields).isNotEmpty) {
        throw _incompatible('unexpected_transaction_fields');
      }
      final String ownerId = _string(data, 'ownerId');
      final FinancialTransaction transaction = FinancialTransaction(
        id: documentId,
        ownerId: ownerId,
        accountId: _string(data, 'accountId'),
        categoryId: _string(data, 'categoryId'),
        kind: FinancialTransactionKind.fromStorage(_string(data, 'kind')),
        description: _string(data, 'description'),
        amountCents: _integer(data, 'amountCents'),
        occurredAt: _dateTime(data, 'occurredAt'),
        notes: _string(data, 'notes'),
        isVoided: _boolean(data, 'isVoided'),
        voidedAt: _nullableDateTime(data, 'voidedAt'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: schemaVersion,
        originType: schemaVersion == FinancialTransaction.currentSchemaVersion
            ? FinancialTransactionOriginType.manual
            : _originType(data, 'originType'),
        originId: schemaVersion == FinancialTransaction.currentSchemaVersion
            ? null
            : _nullableString(data, 'originId'),
      );
      if (ownerId != expectedOwnerId) {
        throw _incompatible('transaction_owner_mismatch');
      }
      FinancialTransaction.validate(transaction, now: now);
      return transaction;
    } on FinancialTransactionFailure {
      rethrow;
    } on Object {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.conversion,
        safeMessage:
            'Encontramos uma inconsistência neste lançamento. Nenhum dado foi alterado.',
        code: 'transaction_conversion_failed',
      );
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required FinancialTransactionDraft draft,
    required DateTime now,
    FinancialTransactionOriginType originType =
        FinancialTransactionOriginType.manual,
    String? originId,
  }) {
    final FinancialTransactionDraft normalized = draft.normalized(now: now);
    if (originType == FinancialTransactionOriginType.manual) {
      if (originId != null) {
        throw _incompatible('manual_transaction_with_origin_id');
      }
    } else if (!_isValidReferenceId(originId)) {
      throw _incompatible('linked_transaction_without_origin_id');
    }
    return <String, Object?>{
      'ownerId': ownerId,
      'accountId': normalized.accountId,
      'categoryId': normalized.categoryId,
      'kind': normalized.kind.name,
      'description': normalized.description,
      'amountCents': normalized.amountCents,
      'occurredAt': Timestamp.fromDate(normalized.occurredAt),
      'notes': normalized.notes,
      'isVoided': false,
      'voidedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': FinancialTransaction.linkedSchemaVersion,
      'originType': originType.name,
      'originId': originId,
    };
  }

  static Map<String, Object> editableMap({
    required FinancialTransactionEdit edit,
    required DateTime now,
  }) {
    final FinancialTransactionEdit normalized = edit.normalized(now: now);
    return <String, Object>{
      'categoryId': normalized.categoryId,
      'description': normalized.description,
      'occurredAt': Timestamp.fromDate(normalized.occurredAt),
      'notes': normalized.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static bool matchesDraft(
    FinancialTransaction transaction,
    FinancialTransactionDraft draft, {
    required DateTime now,
  }) {
    final FinancialTransactionDraft normalized = draft.normalized(now: now);
    return transaction.accountId == normalized.accountId &&
        transaction.categoryId == normalized.categoryId &&
        transaction.kind == normalized.kind &&
        transaction.description == normalized.description &&
        transaction.amountCents == normalized.amountCents &&
        transaction.occurredAt == normalized.occurredAt &&
        transaction.notes == normalized.notes &&
        transaction.originType == FinancialTransactionOriginType.manual &&
        transaction.originId == null &&
        !transaction.isVoided;
  }

  static FinancialTransactionOriginType _originType(
    Map<String, dynamic> data,
    String field,
  ) {
    final String value = _string(data, field);
    return FinancialTransactionOriginType.values.firstWhere(
      (FinancialTransactionOriginType type) => type.name == value,
      orElse: () => throw StateError('invalid_origin_type'),
    );
  }

  static bool _isValidReferenceId(String? value) =>
      value != null &&
      value.isNotEmpty &&
      value.length <= 150 &&
      !value.contains('/');

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

  static String? _nullableString(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw StateError('invalid_nullable_string');
    }
    return value;
  }

  static FinancialTransactionFailure _incompatible(
    String code,
  ) => FinancialTransactionFailure(
    kind: FinancialTransactionFailureKind.incompatible,
    safeMessage:
        'Encontramos uma inconsistência neste lançamento. Nenhum dado foi alterado.',
    code: code,
  );
}
