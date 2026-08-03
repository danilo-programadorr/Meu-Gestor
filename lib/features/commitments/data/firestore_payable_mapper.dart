import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_commitment_mapper_support.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

abstract final class FirestorePayableMapper {
  static const String movementField = 'paidAt';
  static const Set<String> fieldNames = <String>{
    ...FirestoreCommitmentMapperSupport.commonFields,
    movementField,
  };

  static Payable fromMap({
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
      final Payable payable = Payable(
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
        paidDate: _nullableCivilDate(data, movementField),
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
          'payable_owner_mismatch',
        );
      }
      Payable.validate(payable, today: today);
      return payable;
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

  static bool matchesDraft(Payable payable, FinancialCommitmentDraft draft) =>
      FirestoreCommitmentMapperSupport.matchesDraft(payable, draft);

  static PayableStatus _status(Map<String, dynamic> data) {
    final String value = FirestoreCommitmentMapperSupport.string(
      data,
      'status',
    );
    return PayableStatus.values.firstWhere(
      (PayableStatus status) => status.name == value,
      orElse: () => throw StateError('invalid_payable_status'),
    );
  }

  static SaoPauloCivilDate? _nullableCivilDate(
    Map<String, dynamic> data,
    String field,
  ) => data[field] == null
      ? null
      : FirestoreCommitmentMapperSupport.civilDate(data, field);
}
