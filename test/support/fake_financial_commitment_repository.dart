import 'dart:async';

import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

final class FakeFinancialCommitmentRepository
    implements FinancialCommitmentRepository {
  FakeFinancialCommitmentRepository({
    List<Payable>? initialPayables,
    List<Receivable>? initialReceivables,
  }) : payables = List<Payable>.of(initialPayables ?? <Payable>[]),
       receivables = List<Receivable>.of(initialReceivables ?? <Receivable>[]);

  final List<Payable> payables;
  final List<Receivable> receivables;
  final List<FinancialTransaction> linkedTransactions =
      <FinancialTransaction>[];
  FinancialCommitmentFailure? nextFailure;
  FinancialCommitmentFailure? readFailure;
  Completer<void>? mutationBarrier;
  bool serverConfirmed = true;
  bool pendingWrites = false;
  int createCalls = 0;
  int settleCalls = 0;
  int voidCalls = 0;
  int generatedPayableIds = 0;
  int generatedReceivableIds = 0;
  int generatedTransactionIds = 0;

  @override
  String newPayableId({required String ownerId}) =>
      'payable-generated-${++generatedPayableIds}';

  @override
  String newReceivableId({required String ownerId}) =>
      'receivable-generated-${++generatedReceivableIds}';

  @override
  String newLinkedTransactionId({required String ownerId}) =>
      'transaction-generated-${++generatedTransactionIds}';

  @override
  Future<FinancialCommitmentsReadResult<Payable>> readOwnPayables({
    required String ownerId,
    required bool serverOnly,
  }) async {
    _throwReadIfNeeded();
    _throwIfNeeded();
    return FinancialCommitmentsReadResult<Payable>(
      commitments: payables
          .where((Payable item) => item.ownerId == ownerId)
          .toList(growable: false),
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<FinancialCommitmentsReadResult<Receivable>> readOwnReceivables({
    required String ownerId,
    required bool serverOnly,
  }) async {
    _throwReadIfNeeded();
    _throwIfNeeded();
    return FinancialCommitmentsReadResult<Receivable>(
      commitments: receivables
          .where((Receivable item) => item.ownerId == ownerId)
          .toList(growable: false),
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<Payable> readOwnPayable({
    required String ownerId,
    required String payableId,
    required bool serverOnly,
  }) async => _findPayable(ownerId, payableId);

  @override
  Future<Receivable> readOwnReceivable({
    required String ownerId,
    required String receivableId,
    required bool serverOnly,
  }) async => _findReceivable(ownerId, receivableId);

  @override
  Future<Payable> createPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentDraft draft,
  }) async {
    createCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final Payable? existing = _nullablePayable(ownerId, payableId);
    if (existing != null) {
      return existing;
    }
    final FinancialCommitmentDraft normalized = draft.normalized();
    final DateTime timestamp = DateTime.utc(2026, 8, 15, 15);
    final Payable created = Payable(
      id: payableId,
      ownerId: ownerId,
      description: normalized.description,
      categoryId: normalized.categoryId,
      amountCents: normalized.amountCents,
      dueDate: normalized.dueDate,
      notes: normalized.notes,
      status: PayableStatus.pending,
      paidDate: null,
      linkedTransactionId: null,
      cancelledAt: null,
      voidedAt: null,
      revision: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: FinancialCommitment.currentSchemaVersion,
    );
    payables.add(created);
    return created;
  }

  @override
  Future<Receivable> createReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentDraft draft,
  }) async {
    createCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final Receivable? existing = _nullableReceivable(ownerId, receivableId);
    if (existing != null) {
      return existing;
    }
    final FinancialCommitmentDraft normalized = draft.normalized();
    final DateTime timestamp = DateTime.utc(2026, 8, 15, 15);
    final Receivable created = Receivable(
      id: receivableId,
      ownerId: ownerId,
      description: normalized.description,
      categoryId: normalized.categoryId,
      amountCents: normalized.amountCents,
      dueDate: normalized.dueDate,
      notes: normalized.notes,
      status: ReceivableStatus.pending,
      receivedDate: null,
      linkedTransactionId: null,
      cancelledAt: null,
      voidedAt: null,
      revision: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: FinancialCommitment.currentSchemaVersion,
    );
    receivables.add(created);
    return created;
  }

  @override
  Future<Payable> updatePendingPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentUpdate update,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _payableIndex(ownerId, payableId);
    final Payable current = payables[index];
    _requirePendingRevision(current, update.expectedRevision);
    final FinancialCommitmentUpdate normalized = update.normalized();
    payables[index] = _copyPayable(
      current,
      description: normalized.description,
      categoryId: normalized.categoryId,
      amountCents: normalized.amountCents,
      dueDate: normalized.dueDate,
      notes: normalized.notes,
      revision: current.revision + 1,
    );
    return payables[index];
  }

  @override
  Future<Receivable> updatePendingReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentUpdate update,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _receivableIndex(ownerId, receivableId);
    final Receivable current = receivables[index];
    _requirePendingRevision(current, update.expectedRevision);
    final FinancialCommitmentUpdate normalized = update.normalized();
    receivables[index] = _copyReceivable(
      current,
      description: normalized.description,
      categoryId: normalized.categoryId,
      amountCents: normalized.amountCents,
      dueDate: normalized.dueDate,
      notes: normalized.notes,
      revision: current.revision + 1,
    );
    return receivables[index];
  }

  @override
  Future<FinancialCommitmentMutationResult<Payable>> pay({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentSettlementCommand command,
  }) async {
    settleCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _payableIndex(ownerId, payableId);
    final Payable current = payables[index];
    if (current.isSettled) {
      return FinancialCommitmentMutationResult<Payable>(
        commitment: current,
        linkedTransaction: _linked(current.linkedTransactionId!),
      );
    }
    _requirePendingRevision(current, command.expectedRevision);
    final Payable settled = _copyPayable(
      current,
      status: PayableStatus.paid,
      paidDate: command.movementDate,
      settlementAccountId: command.accountId,
      linkedTransactionId: command.transactionId,
      revision: current.revision + 1,
    );
    payables[index] = settled;
    final FinancialTransaction transaction = _createLinkedTransaction(
      commitment: settled,
      transactionId: command.transactionId,
      accountId: command.accountId,
      movementDate: command.movementDate,
    );
    return FinancialCommitmentMutationResult<Payable>(
      commitment: settled,
      linkedTransaction: transaction,
    );
  }

  @override
  Future<FinancialCommitmentMutationResult<Receivable>> receive({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentSettlementCommand command,
  }) async {
    settleCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _receivableIndex(ownerId, receivableId);
    final Receivable current = receivables[index];
    if (current.isSettled) {
      return FinancialCommitmentMutationResult<Receivable>(
        commitment: current,
        linkedTransaction: _linked(current.linkedTransactionId!),
      );
    }
    _requirePendingRevision(current, command.expectedRevision);
    final Receivable settled = _copyReceivable(
      current,
      status: ReceivableStatus.received,
      receivedDate: command.movementDate,
      settlementAccountId: command.accountId,
      linkedTransactionId: command.transactionId,
      revision: current.revision + 1,
    );
    receivables[index] = settled;
    final FinancialTransaction transaction = _createLinkedTransaction(
      commitment: settled,
      transactionId: command.transactionId,
      accountId: command.accountId,
      movementDate: command.movementDate,
    );
    return FinancialCommitmentMutationResult<Receivable>(
      commitment: settled,
      linkedTransaction: transaction,
    );
  }

  @override
  Future<Payable> cancelPendingPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _payableIndex(ownerId, payableId);
    final Payable current = payables[index];
    _requirePendingRevision(current, expectedRevision);
    payables[index] = _copyPayable(
      current,
      status: PayableStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 15, 15),
      revision: current.revision + 1,
    );
    return payables[index];
  }

  @override
  Future<Receivable> cancelPendingReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _receivableIndex(ownerId, receivableId);
    final Receivable current = receivables[index];
    _requirePendingRevision(current, expectedRevision);
    receivables[index] = _copyReceivable(
      current,
      status: ReceivableStatus.cancelled,
      cancelledAt: DateTime.utc(2026, 8, 15, 15),
      revision: current.revision + 1,
    );
    return receivables[index];
  }

  @override
  Future<FinancialCommitmentMutationResult<Payable>> voidPaidPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  }) async {
    voidCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _payableIndex(ownerId, payableId);
    final Payable current = payables[index];
    _requireSettledRevision(current, expectedRevision);
    final FinancialTransaction voided = _voidLinked(
      current.linkedTransactionId!,
    );
    payables[index] = _copyPayable(
      current,
      status: PayableStatus.voided,
      voidedAt: DateTime.utc(2026, 8, 15, 15),
      revision: current.revision + 1,
    );
    return FinancialCommitmentMutationResult<Payable>(
      commitment: payables[index],
      linkedTransaction: voided,
    );
  }

  @override
  Future<FinancialCommitmentMutationResult<Receivable>> voidReceivedReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  }) async {
    voidCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _receivableIndex(ownerId, receivableId);
    final Receivable current = receivables[index];
    _requireSettledRevision(current, expectedRevision);
    final FinancialTransaction voided = _voidLinked(
      current.linkedTransactionId!,
    );
    receivables[index] = _copyReceivable(
      current,
      status: ReceivableStatus.voided,
      voidedAt: DateTime.utc(2026, 8, 15, 15),
      revision: current.revision + 1,
    );
    return FinancialCommitmentMutationResult<Receivable>(
      commitment: receivables[index],
      linkedTransaction: voided,
    );
  }

  FinancialTransaction _createLinkedTransaction({
    required FinancialCommitment commitment,
    required String transactionId,
    required String accountId,
    required SaoPauloCivilDate movementDate,
  }) {
    final DateTime timestamp = DateTime.utc(2026, 8, 15, 15);
    final FinancialTransaction transaction = FinancialTransaction(
      id: transactionId,
      ownerId: commitment.ownerId,
      accountId: accountId,
      categoryId: commitment.categoryId,
      kind: commitment.kind == FinancialCommitmentKind.payable
          ? FinancialTransactionKind.expense
          : FinancialTransactionKind.income,
      description: commitment.description,
      amountCents: commitment.amountCents,
      occurredAt: movementDate.toStorageInstant(),
      notes: commitment.notes,
      isVoided: false,
      voidedAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: FinancialTransaction.linkedSchemaVersion,
      originType: commitment.kind == FinancialCommitmentKind.payable
          ? FinancialTransactionOriginType.payable
          : FinancialTransactionOriginType.receivable,
      originId: commitment.id,
    );
    linkedTransactions.add(transaction);
    return transaction;
  }

  FinancialTransaction _voidLinked(String id) {
    final int index = linkedTransactions.indexWhere(
      (FinancialTransaction item) => item.id == id,
    );
    if (index < 0) {
      throw const FinancialCommitmentFailure(
        kind: FinancialCommitmentFailureKind.notFound,
        safeMessage: 'Lançamento vinculado não encontrado.',
        code: 'fake_linked_transaction_not_found',
      );
    }
    final FinancialTransaction current = linkedTransactions[index];
    linkedTransactions[index] = current.copyWith(
      isVoided: true,
      voidedAt: DateTime.utc(2026, 8, 15, 15),
      updatedAt: DateTime.utc(2026, 8, 15, 15),
    );
    return linkedTransactions[index];
  }

  FinancialTransaction _linked(String id) => linkedTransactions.firstWhere(
    (FinancialTransaction item) => item.id == id,
  );

  void _requirePendingRevision(FinancialCommitment item, int revision) {
    if (!item.isPending || item.revision != revision) {
      throw _conflict();
    }
  }

  void _requireSettledRevision(FinancialCommitment item, int revision) {
    if (!item.isSettled || item.revision != revision) {
      throw _conflict();
    }
  }

  FinancialCommitmentFailure _conflict() => const FinancialCommitmentFailure(
    kind: FinancialCommitmentFailureKind.conflict,
    safeMessage: 'O compromisso foi alterado. Atualize e tente novamente.',
    code: 'fake_revision_conflict',
  );

  Future<void> _waitMutation() async {
    final Completer<void>? barrier = mutationBarrier;
    if (barrier != null) {
      await barrier.future;
    }
  }

  void _throwIfNeeded() {
    final FinancialCommitmentFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }

  void _throwReadIfNeeded() {
    final FinancialCommitmentFailure? failure = readFailure;
    if (failure != null) {
      throw failure;
    }
  }

  Payable _findPayable(String ownerId, String id) =>
      _nullablePayable(ownerId, id) ?? (throw _notFound());

  Receivable _findReceivable(String ownerId, String id) =>
      _nullableReceivable(ownerId, id) ?? (throw _notFound());

  Payable? _nullablePayable(String ownerId, String id) {
    for (final Payable item in payables) {
      if (item.ownerId == ownerId && item.id == id) {
        return item;
      }
    }
    return null;
  }

  Receivable? _nullableReceivable(String ownerId, String id) {
    for (final Receivable item in receivables) {
      if (item.ownerId == ownerId && item.id == id) {
        return item;
      }
    }
    return null;
  }

  int _payableIndex(String ownerId, String id) => payables.indexWhere(
    (Payable item) => item.ownerId == ownerId && item.id == id,
  );

  int _receivableIndex(String ownerId, String id) => receivables.indexWhere(
    (Receivable item) => item.ownerId == ownerId && item.id == id,
  );

  FinancialCommitmentFailure _notFound() => const FinancialCommitmentFailure(
    kind: FinancialCommitmentFailureKind.notFound,
    safeMessage: 'Compromisso não encontrado.',
    code: 'fake_commitment_not_found',
  );

  Payable _copyPayable(
    Payable current, {
    String? description,
    String? categoryId,
    int? amountCents,
    SaoPauloCivilDate? dueDate,
    String? notes,
    PayableStatus? status,
    SaoPauloCivilDate? paidDate,
    String? settlementAccountId,
    String? linkedTransactionId,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    int? revision,
  }) => Payable(
    id: current.id,
    ownerId: current.ownerId,
    description: description ?? current.description,
    categoryId: categoryId ?? current.categoryId,
    amountCents: amountCents ?? current.amountCents,
    dueDate: dueDate ?? current.dueDate,
    notes: notes ?? current.notes,
    status: status ?? current.status,
    paidDate: paidDate ?? current.paidDate,
    settlementAccountId: settlementAccountId ?? current.settlementAccountId,
    linkedTransactionId: linkedTransactionId ?? current.linkedTransactionId,
    cancelledAt: cancelledAt ?? current.cancelledAt,
    voidedAt: voidedAt ?? current.voidedAt,
    revision: revision ?? current.revision,
    createdAt: current.createdAt,
    updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    schemaVersion: current.schemaVersion,
  );

  Receivable _copyReceivable(
    Receivable current, {
    String? description,
    String? categoryId,
    int? amountCents,
    SaoPauloCivilDate? dueDate,
    String? notes,
    ReceivableStatus? status,
    SaoPauloCivilDate? receivedDate,
    String? settlementAccountId,
    String? linkedTransactionId,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    int? revision,
  }) => Receivable(
    id: current.id,
    ownerId: current.ownerId,
    description: description ?? current.description,
    categoryId: categoryId ?? current.categoryId,
    amountCents: amountCents ?? current.amountCents,
    dueDate: dueDate ?? current.dueDate,
    notes: notes ?? current.notes,
    status: status ?? current.status,
    receivedDate: receivedDate ?? current.receivedDate,
    settlementAccountId: settlementAccountId ?? current.settlementAccountId,
    linkedTransactionId: linkedTransactionId ?? current.linkedTransactionId,
    cancelledAt: cancelledAt ?? current.cancelledAt,
    voidedAt: voidedAt ?? current.voidedAt,
    revision: revision ?? current.revision,
    createdAt: current.createdAt,
    updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    schemaVersion: current.schemaVersion,
  );
}
