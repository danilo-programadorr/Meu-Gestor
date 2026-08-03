import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';

Payable createTestPayable({
  String id = 'payable-1',
  String ownerId = 'owner',
  String description = 'Conta de energia',
  String categoryId = 'expense-category',
  int amountCents = 12500,
  SaoPauloCivilDate? dueDate,
  PayableStatus status = PayableStatus.pending,
  SaoPauloCivilDate? paidDate,
  String? settlementAccountId,
  String? linkedTransactionId,
  int revision = 1,
}) {
  final DateTime createdAt = DateTime.utc(2026, 8, 1, 12);
  final bool cancelled = status == PayableStatus.cancelled;
  final bool voided = status == PayableStatus.voided;
  return Payable(
    id: id,
    ownerId: ownerId,
    description: description,
    categoryId: categoryId,
    amountCents: amountCents,
    dueDate: dueDate ?? SaoPauloCivilDate(year: 2026, month: 8, day: 10),
    notes: '',
    status: status,
    paidDate: paidDate,
    settlementAccountId: settlementAccountId,
    linkedTransactionId: linkedTransactionId,
    cancelledAt: cancelled ? createdAt.add(const Duration(days: 1)) : null,
    voidedAt: voided ? createdAt.add(const Duration(days: 2)) : null,
    revision: revision,
    createdAt: createdAt,
    updatedAt: cancelled || voided
        ? createdAt.add(const Duration(days: 2))
        : createdAt,
    schemaVersion: FinancialCommitment.currentSchemaVersion,
  );
}

Receivable createTestReceivable({
  String id = 'receivable-1',
  String ownerId = 'owner',
  String description = 'Serviço prestado',
  String categoryId = 'income-category',
  int amountCents = 25000,
  SaoPauloCivilDate? dueDate,
  ReceivableStatus status = ReceivableStatus.pending,
  SaoPauloCivilDate? receivedDate,
  String? settlementAccountId,
  String? linkedTransactionId,
  int revision = 1,
}) {
  final DateTime createdAt = DateTime.utc(2026, 8, 1, 12);
  final bool cancelled = status == ReceivableStatus.cancelled;
  final bool voided = status == ReceivableStatus.voided;
  return Receivable(
    id: id,
    ownerId: ownerId,
    description: description,
    categoryId: categoryId,
    amountCents: amountCents,
    dueDate: dueDate ?? SaoPauloCivilDate(year: 2026, month: 8, day: 20),
    notes: '',
    status: status,
    receivedDate: receivedDate,
    settlementAccountId: settlementAccountId,
    linkedTransactionId: linkedTransactionId,
    cancelledAt: cancelled ? createdAt.add(const Duration(days: 1)) : null,
    voidedAt: voided ? createdAt.add(const Duration(days: 2)) : null,
    revision: revision,
    createdAt: createdAt,
    updatedAt: cancelled || voided
        ? createdAt.add(const Duration(days: 2))
        : createdAt,
    schemaVersion: FinancialCommitment.currentSchemaVersion,
  );
}
