import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

enum FinancialCommitmentKind { payable, receivable }

enum PayableStatus { pending, paid, cancelled, voided }

enum ReceivableStatus { pending, received, cancelled, voided }

sealed class FinancialCommitment {
  const FinancialCommitment({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.categoryId,
    required this.amountCents,
    required this.dueDate,
    required this.notes,
    this.settlementAccountId,
    required this.linkedTransactionId,
    required this.cancelledAt,
    required this.voidedAt,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static const int maximumAmountCents = 9999999999;

  final String id;
  final String ownerId;
  final String description;
  final String categoryId;
  final int amountCents;
  final SaoPauloCivilDate dueDate;
  final String notes;
  final String? settlementAccountId;
  final String? linkedTransactionId;
  final DateTime? cancelledAt;
  final DateTime? voidedAt;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  FinancialCommitmentKind get kind;

  SaoPauloCivilDate? get movementDate;

  bool get isPending;

  bool get isSettled;

  bool get isCancelled;

  bool get isVoided;

  Money get amount => Money.fromCents(amountCents);

  bool get contributesToRealBalance => false;

  bool isOverdue(SaoPauloCivilDate today) =>
      isPending && dueDate.isBefore(today);
}

final class Payable extends FinancialCommitment {
  const Payable({
    required super.id,
    required super.ownerId,
    required super.description,
    required super.categoryId,
    required super.amountCents,
    required super.dueDate,
    required super.notes,
    required this.status,
    required this.paidDate,
    super.settlementAccountId,
    required super.linkedTransactionId,
    required super.cancelledAt,
    required super.voidedAt,
    required super.revision,
    required super.createdAt,
    required super.updatedAt,
    required super.schemaVersion,
  });

  final PayableStatus status;
  final SaoPauloCivilDate? paidDate;

  @override
  FinancialCommitmentKind get kind => FinancialCommitmentKind.payable;

  @override
  SaoPauloCivilDate? get movementDate => paidDate;

  @override
  bool get isPending => status == PayableStatus.pending;

  @override
  bool get isSettled => status == PayableStatus.paid;

  @override
  bool get isCancelled => status == PayableStatus.cancelled;

  @override
  bool get isVoided => status == PayableStatus.voided;

  static void validate(Payable payable, {required SaoPauloCivilDate today}) {
    _validateCommon(payable, today: today);
    switch (payable.status) {
      case PayableStatus.pending:
        _requirePendingState(payable);
      case PayableStatus.paid:
        _requireSettledState(payable, movementDate: payable.paidDate);
      case PayableStatus.cancelled:
        _requireCancelledState(payable);
      case PayableStatus.voided:
        _requireVoidedState(payable, movementDate: payable.paidDate);
    }
  }
}

final class Receivable extends FinancialCommitment {
  const Receivable({
    required super.id,
    required super.ownerId,
    required super.description,
    required super.categoryId,
    required super.amountCents,
    required super.dueDate,
    required super.notes,
    required this.status,
    required this.receivedDate,
    super.settlementAccountId,
    required super.linkedTransactionId,
    required super.cancelledAt,
    required super.voidedAt,
    required super.revision,
    required super.createdAt,
    required super.updatedAt,
    required super.schemaVersion,
  });

  final ReceivableStatus status;
  final SaoPauloCivilDate? receivedDate;

  @override
  FinancialCommitmentKind get kind => FinancialCommitmentKind.receivable;

  @override
  SaoPauloCivilDate? get movementDate => receivedDate;

  @override
  bool get isPending => status == ReceivableStatus.pending;

  @override
  bool get isSettled => status == ReceivableStatus.received;

  @override
  bool get isCancelled => status == ReceivableStatus.cancelled;

  @override
  bool get isVoided => status == ReceivableStatus.voided;

  static void validate(
    Receivable receivable, {
    required SaoPauloCivilDate today,
  }) {
    _validateCommon(receivable, today: today);
    switch (receivable.status) {
      case ReceivableStatus.pending:
        _requirePendingState(receivable);
      case ReceivableStatus.received:
        _requireSettledState(receivable, movementDate: receivable.receivedDate);
      case ReceivableStatus.cancelled:
        _requireCancelledState(receivable);
      case ReceivableStatus.voided:
        _requireVoidedState(receivable, movementDate: receivable.receivedDate);
    }
  }
}

final class FinancialCommitmentDraft {
  const FinancialCommitmentDraft({
    required this.description,
    required this.categoryId,
    required this.amountCents,
    required this.dueDate,
    required this.notes,
  });

  final String description;
  final String categoryId;
  final int amountCents;
  final SaoPauloCivilDate dueDate;
  final String notes;

  FinancialCommitmentDraft normalized() => FinancialCommitmentDraft(
    description: _requireDescription(description),
    categoryId: _requireReferenceId(categoryId, field: 'categoria'),
    amountCents: _requireAmount(amountCents),
    dueDate: dueDate,
    notes: _requireNotes(notes),
  );
}

final class FinancialCommitmentUpdate {
  const FinancialCommitmentUpdate({
    required this.description,
    required this.categoryId,
    required this.amountCents,
    required this.dueDate,
    required this.notes,
    required this.expectedRevision,
  });

  final String description;
  final String categoryId;
  final int amountCents;
  final SaoPauloCivilDate dueDate;
  final String notes;
  final int expectedRevision;

  FinancialCommitmentUpdate normalized() {
    _requireRevision(expectedRevision);
    final FinancialCommitmentDraft draft = FinancialCommitmentDraft(
      description: description,
      categoryId: categoryId,
      amountCents: amountCents,
      dueDate: dueDate,
      notes: notes,
    ).normalized();
    return FinancialCommitmentUpdate(
      description: draft.description,
      categoryId: draft.categoryId,
      amountCents: draft.amountCents,
      dueDate: draft.dueDate,
      notes: draft.notes,
      expectedRevision: expectedRevision,
    );
  }
}

final class FinancialCommitmentSettlementCommand {
  const FinancialCommitmentSettlementCommand({
    required this.transactionId,
    required this.accountId,
    required this.movementDate,
    required this.expectedRevision,
  });

  final String transactionId;
  final String accountId;
  final SaoPauloCivilDate movementDate;
  final int expectedRevision;

  FinancialCommitmentSettlementCommand normalized({
    required SaoPauloCivilDate today,
  }) {
    if (movementDate.isAfter(today)) {
      throw const FinancialCommitmentFailure(
        kind: FinancialCommitmentFailureKind.invalidDate,
        safeMessage: 'A data da movimentação não pode estar no futuro.',
        code: 'commitment_movement_date_in_future',
      );
    }
    _requireRevision(expectedRevision);
    return FinancialCommitmentSettlementCommand(
      transactionId: _requireReferenceId(transactionId, field: 'lançamento'),
      accountId: _requireReferenceId(accountId, field: 'conta'),
      movementDate: movementDate,
      expectedRevision: expectedRevision,
    );
  }
}

void _validateCommon(
  FinancialCommitment commitment, {
  required SaoPauloCivilDate today,
}) {
  _requireReferenceId(commitment.id, field: 'compromisso');
  _requireReferenceId(commitment.ownerId, field: 'proprietário');
  _requireReferenceId(commitment.categoryId, field: 'categoria');
  if (_requireDescription(commitment.description) != commitment.description ||
      _requireNotes(commitment.notes) != commitment.notes ||
      _requireAmount(commitment.amountCents) != commitment.amountCents ||
      commitment.schemaVersion != FinancialCommitment.currentSchemaVersion ||
      commitment.updatedAt.isBefore(commitment.createdAt)) {
    throw _incompatible('invalid_commitment_common_fields');
  }
  _requireRevision(commitment.revision);
  if (commitment.movementDate?.isAfter(today) ?? false) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidDate,
      safeMessage: 'A data da movimentação não pode estar no futuro.',
      code: 'commitment_movement_date_in_future',
    );
  }
}

void _requirePendingState(FinancialCommitment commitment) {
  if (commitment.settlementAccountId != null ||
      commitment.linkedTransactionId != null ||
      commitment.movementDate != null ||
      commitment.cancelledAt != null ||
      commitment.voidedAt != null) {
    throw _incompatible('invalid_pending_commitment');
  }
}

void _requireSettledState(
  FinancialCommitment commitment, {
  required SaoPauloCivilDate? movementDate,
}) {
  if (commitment.linkedTransactionId == null ||
      commitment.settlementAccountId == null ||
      movementDate == null ||
      commitment.cancelledAt != null ||
      commitment.voidedAt != null) {
    throw _incompatible('invalid_settled_commitment');
  }
  _requireReferenceId(
    commitment.linkedTransactionId!,
    field: 'lançamento vinculado',
  );
  _requireReferenceId(
    commitment.settlementAccountId!,
    field: 'conta de liquidação',
  );
}

void _requireCancelledState(FinancialCommitment commitment) {
  if (commitment.settlementAccountId != null ||
      commitment.linkedTransactionId != null ||
      commitment.movementDate != null ||
      commitment.cancelledAt == null ||
      commitment.voidedAt != null ||
      commitment.cancelledAt!.isBefore(commitment.createdAt) ||
      commitment.updatedAt.isBefore(commitment.cancelledAt!)) {
    throw _incompatible('invalid_cancelled_commitment');
  }
}

void _requireVoidedState(
  FinancialCommitment commitment, {
  required SaoPauloCivilDate? movementDate,
}) {
  if (commitment.linkedTransactionId == null ||
      commitment.settlementAccountId == null ||
      movementDate == null ||
      commitment.cancelledAt != null ||
      commitment.voidedAt == null ||
      commitment.voidedAt!.isBefore(commitment.createdAt) ||
      commitment.updatedAt.isBefore(commitment.voidedAt!)) {
    throw _incompatible('invalid_voided_commitment');
  }
  _requireReferenceId(
    commitment.linkedTransactionId!,
    field: 'lançamento vinculado',
  );
  _requireReferenceId(
    commitment.settlementAccountId!,
    field: 'conta de liquidação',
  );
}

int _requireAmount(int amountCents) {
  if (amountCents <= 0 ||
      amountCents > FinancialCommitment.maximumAmountCents) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidAmount,
      safeMessage: 'Informe um valor maior que zero.',
      code: 'commitment_amount_out_of_range',
    );
  }
  return amountCents;
}

String _requireDescription(String value) {
  if (_hasControlCharacter(value)) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidDescription,
      safeMessage: 'A descrição contém caracteres não permitidos.',
      code: 'invalid_commitment_description',
    );
  }
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length < 2 || normalized.length > 120) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidDescription,
      safeMessage: 'Informe uma descrição entre 2 e 120 caracteres.',
      code: 'invalid_commitment_description',
    );
  }
  return normalized;
}

String _requireNotes(String value) {
  if (_hasControlCharacter(value)) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidNotes,
      safeMessage: 'As observações contêm caracteres não permitidos.',
      code: 'invalid_commitment_notes',
    );
  }
  final String normalized = value.trim();
  if (normalized.length > 500) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.invalidNotes,
      safeMessage: 'As observações devem ter no máximo 500 caracteres.',
      code: 'invalid_commitment_notes',
    );
  }
  return normalized;
}

String _requireReferenceId(String value, {required String field}) {
  if (value.isEmpty || value.length > 150 || value.contains('/')) {
    throw FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.validation,
      safeMessage: 'A referência de $field é inválida.',
      code: 'invalid_commitment_reference',
    );
  }
  return value;
}

void _requireRevision(int revision) {
  if (revision < 1) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.incompatible,
      safeMessage: 'A versão do compromisso é incompatível.',
      code: 'invalid_commitment_revision',
    );
  }
}

bool _hasControlCharacter(String value) =>
    RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);

FinancialCommitmentFailure _incompatible(String code) =>
    FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.incompatible,
      safeMessage: 'Encontramos uma inconsistência neste compromisso.',
      code: code,
    );
