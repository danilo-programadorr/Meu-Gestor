import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_commitment_mapper_support.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

abstract final class FirestoreReceivableMapper {
  static const String movementField = 'receivedAt';
  static const Set<String> fieldNames = <String>{
    ...FirestoreCommitmentMapperSupport.commonFields,
    movementField,
  };

  static Receivable fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
    required SaoPauloCivilDate today,
  }) {
    try {
      FirestoreCommitmentMapperSupport.requireExactFields(data, fieldNames);
      final String ownerId = FirestoreCommitmentMapperSupport.string(
        data,
        'ownerId',
      );
      final Receivable receivable = Receivable(
        id: documentId,
        ownerId: ownerId,
        description: FirestoreCommitmentMapperSupport.string(
          data,
          'description',
        ),
        categoryId: FirestoreCommitmentMapperSupport.string(data, 'categoryId'),
        amountCents: FirestoreCommitmentMapperSupport.integer(
          data,
          'amountCents',
        ),
        dueDate: FirestoreCommitmentMapperSupport.civilDate(data, 'dueAt'),
        notes: FirestoreCommitmentMapperSupport.string(data, 'notes'),
        status: _status(data),
        receivedDate: _nullableCivilDate(data, movementField),
        settlementAccountId: FirestoreCommitmentMapperSupport.nullableString(
          data,
          'settlementAccountId',
        ),
        linkedTransactionId: FirestoreCommitmentMapperSupport.nullableString(
          data,
          'linkedTransactionId',
        ),
        cancelledAt: FirestoreCommitmentMapperSupport.nullableDateTime(
          data,
          'cancelledAt',
        ),
        voidedAt: FirestoreCommitmentMapperSupport.nullableDateTime(
          data,
          'voidedAt',
        ),
        revision: FirestoreCommitmentMapperSupport.integer(data, 'revision'),
        createdAt: FirestoreCommitmentMapperSupport.dateTime(data, 'createdAt'),
        updatedAt: FirestoreCommitmentMapperSupport.dateTime(data, 'updatedAt'),
        schemaVersion: FirestoreCommitmentMapperSupport.integer(
          data,
          'schemaVersion',
        ),
      );
      if (ownerId != expectedOwnerId) {
        throw FirestoreCommitmentMapperSupport.incompatible(
          'receivable_owner_mismatch',
        );
      }
      Receivable.validate(receivable, today: today);
      return receivable;
    } on FinancialCommitmentFailure {
      rethrow;
    } on Object {
      throw FirestoreCommitmentMapperSupport.conversionFailure();
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required FinancialCommitmentDraft draft,
  }) => FirestoreCommitmentMapperSupport.creationMap(
    ownerId: ownerId,
    draft: draft,
    movementField: movementField,
  );

  static bool matchesDraft(
    Receivable receivable,
    FinancialCommitmentDraft draft,
  ) => FirestoreCommitmentMapperSupport.matchesDraft(receivable, draft);

  static ReceivableStatus _status(Map<String, dynamic> data) {
    final String value = FirestoreCommitmentMapperSupport.string(
      data,
      'status',
    );
    return ReceivableStatus.values.firstWhere(
      (ReceivableStatus status) => status.name == value,
      orElse: () => throw StateError('invalid_receivable_status'),
    );
  }

  static SaoPauloCivilDate? _nullableCivilDate(
    Map<String, dynamic> data,
    String field,
  ) => data[field] == null
      ? null
      : FirestoreCommitmentMapperSupport.civilDate(data, field);
}
