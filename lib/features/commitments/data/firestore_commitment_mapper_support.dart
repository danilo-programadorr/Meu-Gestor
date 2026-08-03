import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

abstract final class FirestoreCommitmentMapperSupport {
  static const Set<String> commonFields = <String>{
    'ownerId',
    'description',
    'categoryId',
    'amountCents',
    'dueAt',
    'status',
    'settlementAccountId',
    'linkedTransactionId',
    'cancelledAt',
    'voidedAt',
    'notes',
    'revision',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  static void requireExactFields(
    Map<String, dynamic> data,
    Set<String> expectedFields,
  ) {
    final Set<String> actualFields = data.keys.toSet();
    if (actualFields.difference(expectedFields).isNotEmpty ||
        expectedFields.difference(actualFields).isNotEmpty) {
      throw incompatible('unexpected_commitment_fields');
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required FinancialCommitmentDraft draft,
    required String movementField,
  }) {
    final FinancialCommitmentDraft normalized = draft.normalized();
    return <String, Object?>{
      'ownerId': ownerId,
      'description': normalized.description,
      'categoryId': normalized.categoryId,
      'amountCents': normalized.amountCents,
      'dueAt': Timestamp.fromDate(normalized.dueDate.toStorageInstant()),
      'status': 'pending',
      movementField: null,
      'settlementAccountId': null,
      'linkedTransactionId': null,
      'cancelledAt': null,
      'voidedAt': null,
      'notes': normalized.notes,
      'revision': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': FinancialCommitment.currentSchemaVersion,
    };
  }

  static Map<String, Object?> editableMap(FinancialCommitmentUpdate update) {
    final FinancialCommitmentUpdate normalized = update.normalized();
    return <String, Object?>{
      'description': normalized.description,
      'categoryId': normalized.categoryId,
      'amountCents': normalized.amountCents,
      'dueAt': Timestamp.fromDate(normalized.dueDate.toStorageInstant()),
      'notes': normalized.notes,
      'revision': normalized.expectedRevision + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> settlementMap({
    required String settledStatus,
    required String movementField,
    required FinancialCommitmentSettlementCommand command,
  }) => <String, Object?>{
    'status': settledStatus,
    movementField: Timestamp.fromDate(command.movementDate.toStorageInstant()),
    'settlementAccountId': command.accountId,
    'linkedTransactionId': command.transactionId,
    'revision': command.expectedRevision + 1,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Map<String, Object?> cancellationMap(int expectedRevision) =>
      <String, Object?>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'revision': expectedRevision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Map<String, Object?> voidMap(int expectedRevision) =>
      <String, Object?>{
        'status': 'voided',
        'voidedAt': FieldValue.serverTimestamp(),
        'revision': expectedRevision + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static bool matchesDraft(
    FinancialCommitment commitment,
    FinancialCommitmentDraft draft,
  ) {
    final FinancialCommitmentDraft normalized = draft.normalized();
    return commitment.isPending &&
        commitment.description == normalized.description &&
        commitment.categoryId == normalized.categoryId &&
        commitment.amountCents == normalized.amountCents &&
        commitment.dueDate == normalized.dueDate &&
        commitment.notes == normalized.notes;
  }

  static String string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) {
      throw StateError('invalid_string');
    }
    return value;
  }

  static String? nullableString(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw StateError('invalid_nullable_string');
    }
    return value;
  }

  static int integer(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! int) {
      throw StateError('invalid_integer');
    }
    return value;
  }

  static DateTime dateTime(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! Timestamp) {
      throw StateError('invalid_or_pending_timestamp');
    }
    return value.toDate().toUtc();
  }

  static DateTime? nullableDateTime(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) {
      return null;
    }
    if (value is! Timestamp) {
      throw StateError('invalid_nullable_timestamp');
    }
    return value.toDate().toUtc();
  }

  static SaoPauloCivilDate civilDate(Map<String, dynamic> data, String field) {
    final DateTime instant = dateTime(data, field);
    final SaoPauloCivilDate date = SaoPauloCivilDate.fromInstant(instant);
    if (date.toStorageInstant() != instant) {
      throw StateError('non_canonical_civil_date');
    }
    return date;
  }

  static FinancialCommitmentFailure incompatible(String code) =>
      FinancialCommitmentFailure(
        kind: FinancialCommitmentFailureKind.incompatible,
        safeMessage: 'Encontramos uma inconsistência neste compromisso.',
        code: code,
      );

  static FinancialCommitmentFailure
  conversionFailure() => const FinancialCommitmentFailure(
    kind: FinancialCommitmentFailureKind.incompatible,
    safeMessage:
        'Encontramos uma inconsistência neste compromisso. Nenhum dado foi alterado.',
    code: 'commitment_conversion_failed',
  );
}
