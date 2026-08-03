import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

final class FinancialCommitmentsReadResult<T extends FinancialCommitment> {
  const FinancialCommitmentsReadResult({
    required this.commitments,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<T> commitments;
  final bool isFromServer;
  final bool hasPendingWrites;
}

final class FinancialCommitmentMutationResult<T extends FinancialCommitment> {
  const FinancialCommitmentMutationResult({
    required this.commitment,
    required this.linkedTransaction,
  });

  final T commitment;
  final FinancialTransaction linkedTransaction;
}

abstract interface class FinancialCommitmentRepository {
  String newPayableId({required String ownerId});

  String newReceivableId({required String ownerId});

  String newLinkedTransactionId({required String ownerId});

  Future<FinancialCommitmentsReadResult<Payable>> readOwnPayables({
    required String ownerId,
    required bool serverOnly,
  });

  Future<FinancialCommitmentsReadResult<Receivable>> readOwnReceivables({
    required String ownerId,
    required bool serverOnly,
  });

  Future<Payable> readOwnPayable({
    required String ownerId,
    required String payableId,
    required bool serverOnly,
  });

  Future<Receivable> readOwnReceivable({
    required String ownerId,
    required String receivableId,
    required bool serverOnly,
  });

  Future<Payable> createPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentDraft draft,
  });

  Future<Receivable> createReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentDraft draft,
  });

  Future<Payable> updatePendingPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentUpdate update,
  });

  Future<Receivable> updatePendingReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentUpdate update,
  });

  Future<FinancialCommitmentMutationResult<Payable>> pay({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentSettlementCommand command,
  });

  Future<FinancialCommitmentMutationResult<Receivable>> receive({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentSettlementCommand command,
  });

  Future<Payable> cancelPendingPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  });

  Future<Receivable> cancelPendingReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  });

  Future<FinancialCommitmentMutationResult<Payable>> voidPaidPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  });

  Future<FinancialCommitmentMutationResult<Receivable>> voidReceivedReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  });
}
