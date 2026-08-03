import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_commitment_mapper_support.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_payable_mapper.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_receivable_mapper.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 2,
  );
  final DateTime auditAt = DateTime.utc(2026, 8, 1, 12);

  Map<String, dynamic> pendingMap({required bool payable}) => <String, dynamic>{
    'ownerId': 'owner-1',
    'description': payable ? 'Conta de luz' : 'Serviço prestado',
    'categoryId': payable ? 'expense-category' : 'income-category',
    'amountCents': 12345,
    'dueAt': Timestamp.fromDate(DateTime.utc(2026, 8, 5, 3)),
    'status': 'pending',
    payable ? 'paidAt' : 'receivedAt': null,
    'settlementAccountId': null,
    'linkedTransactionId': null,
    'cancelledAt': null,
    'voidedAt': null,
    'notes': '',
    'revision': 1,
    'createdAt': Timestamp.fromDate(auditAt),
    'updatedAt': Timestamp.fromDate(auditAt),
    'schemaVersion': 1,
  };

  test('converte payable pendente com campos estritos', () {
    final Payable payable = FirestorePayableMapper.fromMap(
      data: pendingMap(payable: true),
      documentId: 'payable-1',
      expectedOwnerId: 'owner-1',
      today: today,
    );

    expect(payable.status, PayableStatus.pending);
    expect(payable.dueDate.toString(), '2026-08-05');
    expect(payable.settlementAccountId, isNull);
  });

  test('converte receivable liquidado com vínculo completo', () {
    final Map<String, dynamic> data = pendingMap(payable: false)
      ..['status'] = 'received'
      ..['receivedAt'] = Timestamp.fromDate(DateTime.utc(2026, 8, 2, 3))
      ..['settlementAccountId'] = 'account-1'
      ..['linkedTransactionId'] = 'transaction-1'
      ..['revision'] = 2;

    final Receivable receivable = FirestoreReceivableMapper.fromMap(
      data: data,
      documentId: 'receivable-1',
      expectedOwnerId: 'owner-1',
      today: today,
    );

    expect(receivable.status, ReceivableStatus.received);
    expect(receivable.settlementAccountId, 'account-1');
    expect(receivable.receivedDate, today);
  });

  for (final String mutation in <String>[
    'missing',
    'extra',
    'owner',
    'double',
    'nonCanonicalDate',
    'invalidState',
    'schema',
  ]) {
    test('rejeita payable incompatível: $mutation', () {
      final Map<String, dynamic> data = pendingMap(payable: true);
      switch (mutation) {
        case 'missing':
          data.remove('notes');
        case 'extra':
          data['overdue'] = true;
        case 'owner':
          data['ownerId'] = 'other-owner';
        case 'double':
          data['amountCents'] = 12.34;
        case 'nonCanonicalDate':
          data['dueAt'] = Timestamp.fromDate(DateTime.utc(2026, 8, 5, 12));
        case 'invalidState':
          data['linkedTransactionId'] = 'transaction-1';
        case 'schema':
          data['schemaVersion'] = 2;
      }
      expect(
        () => FirestorePayableMapper.fromMap(
          data: data,
          documentId: 'payable-1',
          expectedOwnerId: 'owner-1',
          today: today,
        ),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });
  }

  test(
    'mapas de criação, edição e transições usam somente campos esperados',
    () {
      final FinancialCommitmentDraft draft = FinancialCommitmentDraft(
        description: ' Conta de luz ',
        categoryId: 'expense-category',
        amountCents: 12345,
        dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 5),
        notes: '',
      );
      final Map<String, Object?> creation = FirestorePayableMapper.creationMap(
        ownerId: 'owner-1',
        draft: draft,
      );
      final Map<String, Object?> settlement =
          FirestoreCommitmentMapperSupport.settlementMap(
            settledStatus: 'paid',
            movementField: 'paidAt',
            command: FinancialCommitmentSettlementCommand(
              transactionId: 'transaction-1',
              accountId: 'account-1',
              movementDate: today,
              expectedRevision: 1,
            ),
          );

      expect(creation.keys.toSet(), FirestorePayableMapper.fieldNames);
      expect(creation['status'], 'pending');
      expect(creation['createdAt'], isA<FieldValue>());
      expect(settlement.keys.toSet(), <String>{
        'status',
        'paidAt',
        'settlementAccountId',
        'linkedTransactionId',
        'revision',
        'updatedAt',
      });
      expect(settlement['revision'], 2);
      expect(
        FirestoreCommitmentMapperSupport.cancellationMap(2)['revision'],
        3,
      );
      expect(FirestoreCommitmentMapperSupport.voidMap(3)['revision'], 4);
    },
  );
}
