import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firebase_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

void main() {
  final SaoPauloCivilDate movementDate = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 2,
  );
  final DateTime auditAt = DateTime.utc(2026, 8, 2, 12);

  Payable payable({PayableStatus status = PayableStatus.paid}) => Payable(
    id: 'payable-1',
    ownerId: 'owner-1',
    description: 'Conta de luz',
    categoryId: 'category-1',
    amountCents: 12345,
    dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 1),
    notes: '',
    status: status,
    paidDate: movementDate,
    settlementAccountId: 'account-1',
    linkedTransactionId: 'transaction-1',
    cancelledAt: null,
    voidedAt: status == PayableStatus.voided ? auditAt : null,
    revision: status == PayableStatus.voided ? 3 : 2,
    createdAt: DateTime.utc(2026, 8, 1, 12),
    updatedAt: auditAt,
    schemaVersion: 1,
  );

  FinancialTransaction transaction({
    bool isVoided = false,
    String accountId = 'account-1',
    int amountCents = 12345,
    FinancialTransactionOriginType originType =
        FinancialTransactionOriginType.payable,
  }) => FinancialTransaction(
    id: 'transaction-1',
    ownerId: 'owner-1',
    accountId: accountId,
    categoryId: 'category-1',
    kind: FinancialTransactionKind.expense,
    description: 'Conta de luz',
    amountCents: amountCents,
    occurredAt: movementDate.toStorageInstant(),
    notes: '',
    isVoided: isVoided,
    voidedAt: isVoided ? auditAt : null,
    createdAt: auditAt,
    updatedAt: auditAt,
    schemaVersion: 2,
    originType: originType,
    originId: 'payable-1',
  );

  test('aceita par liquidado íntegro e repetível', () {
    expect(
      () => FirebaseCommitmentRepository.validateSettledPair(
        commitment: payable(),
        transaction: transaction(),
        expectedAccountId: 'account-1',
        expectedMovementDate: movementDate,
      ),
      returnsNormally,
    );
  });

  for (final String divergence in <String>[
    'account',
    'amount',
    'origin',
    'voided',
  ]) {
    test('rejeita par divergente: $divergence', () {
      final FinancialTransaction candidate = switch (divergence) {
        'account' => transaction(accountId: 'account-2'),
        'amount' => transaction(amountCents: 999),
        'origin' => transaction(
          originType: FinancialTransactionOriginType.receivable,
        ),
        _ => transaction(isVoided: true),
      };
      expect(
        () => FirebaseCommitmentRepository.validateSettledPair(
          commitment: payable(),
          transaction: candidate,
          expectedAccountId: 'account-1',
          expectedMovementDate: movementDate,
        ),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });
  }

  test('aceita par anulado somente quando ambos estão anulados', () {
    expect(
      () => FirebaseCommitmentRepository.validateSettledPair(
        commitment: payable(status: PayableStatus.voided),
        transaction: transaction(isVoided: true),
        expectedAccountId: 'account-1',
        expectedMovementDate: movementDate,
        allowVoided: true,
      ),
      returnsNormally,
    );
  });

  test('mapeia timeout e conflito de concorrência de forma tipada', () {
    expect(
      FirebaseCommitmentRepository.mapFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded'),
      ).kind,
      FinancialCommitmentFailureKind.timeout,
    );
    expect(
      FirebaseCommitmentRepository.mapFailure(
        FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
      ).kind,
      FinancialCommitmentFailureKind.conflict,
    );
  });
}
