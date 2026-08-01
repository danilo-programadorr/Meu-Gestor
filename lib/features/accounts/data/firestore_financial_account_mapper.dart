import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/account_name.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';

abstract final class FirestoreFinancialAccountMapper {
  static const Set<String> fieldNames = <String>{
    'ownerId',
    'name',
    'type',
    'openingBalanceCents',
    'currencyCode',
    'includeInTotal',
    'isArchived',
    'archivedAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  static FinancialAccount fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
  }) {
    try {
      final Set<String> actualFields = data.keys.toSet();
      if (actualFields.difference(fieldNames).isNotEmpty ||
          fieldNames.difference(actualFields).isNotEmpty) {
        throw _incompatible('unexpected_account_fields');
      }
      final String ownerId = _string(data, 'ownerId');
      final String name = _string(data, 'name');
      final String currencyCode = _string(data, 'currencyCode');
      final int schemaVersion = _integer(data, 'schemaVersion');
      final bool isArchived = _boolean(data, 'isArchived');
      final DateTime? archivedAt = _nullableDateTime(data, 'archivedAt');
      final FinancialAccount account = FinancialAccount(
        id: documentId,
        ownerId: ownerId,
        name: name,
        type: FinancialAccountType.fromStorage(_string(data, 'type')),
        openingBalanceCents: _integer(data, 'openingBalanceCents'),
        currencyCode: currencyCode,
        includeInTotal: _boolean(data, 'includeInTotal'),
        isArchived: isArchived,
        archivedAt: archivedAt,
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: schemaVersion,
      );
      if (ownerId != expectedOwnerId ||
          AccountName.normalize(name) != name ||
          currencyCode != FinancialAccount.supportedCurrencyCode ||
          schemaVersion != FinancialAccount.currentSchemaVersion ||
          isArchived != (archivedAt != null)) {
        throw _incompatible('invalid_account_invariant');
      }
      FinancialAccount.validate(account);
      return account;
    } on FinancialAccountFailure {
      rethrow;
    } on Object {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.conversion,
        safeMessage:
            'Encontramos uma inconsistência nesta conta. Nenhum dado foi alterado.',
        code: 'account_conversion_failed',
      );
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required FinancialAccountDraft draft,
  }) {
    final FinancialAccountDraft normalized = draft.normalized();
    return <String, Object?>{
      'ownerId': ownerId,
      'name': normalized.name,
      'type': normalized.type.name,
      'openingBalanceCents': normalized.openingBalanceCents,
      'currencyCode': FinancialAccount.supportedCurrencyCode,
      'includeInTotal': normalized.includeInTotal,
      'isArchived': false,
      'archivedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': FinancialAccount.currentSchemaVersion,
    };
  }

  static Map<String, Object> editableMap(FinancialAccountDraft draft) {
    final FinancialAccountDraft normalized = draft.normalized();
    return <String, Object>{
      'name': normalized.name,
      'type': normalized.type.name,
      'openingBalanceCents': normalized.openingBalanceCents,
      'includeInTotal': normalized.includeInTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static bool matchesDraft(
    FinancialAccount account,
    FinancialAccountDraft draft,
  ) {
    final FinancialAccountDraft normalized = draft.normalized();
    return account.name == normalized.name &&
        account.type == normalized.type &&
        account.openingBalanceCents == normalized.openingBalanceCents &&
        account.includeInTotal == normalized.includeInTotal;
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

  static FinancialAccountFailure _incompatible(
    String code,
  ) => FinancialAccountFailure(
    kind: FinancialAccountFailureKind.incompatible,
    safeMessage:
        'Encontramos uma inconsistência nesta conta. Nenhum dado foi alterado.',
    code: code,
  );
}
