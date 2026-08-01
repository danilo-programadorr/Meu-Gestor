import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

FinancialTransaction createTestTransaction({
  String id = 'transaction-1',
  String ownerId = 'owner',
  String accountId = 'account-1',
  String categoryId = 'category-1',
  FinancialTransactionKind kind = FinancialTransactionKind.income,
  String description = 'Salário mensal',
  int amountCents = 250000,
  DateTime? occurredAt,
  String notes = '',
  bool isVoided = false,
}) {
  final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
  return FinancialTransaction(
    id: id,
    ownerId: ownerId,
    accountId: accountId,
    categoryId: categoryId,
    kind: kind,
    description: description,
    amountCents: amountCents,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 1, 3),
    notes: notes,
    isVoided: isVoided,
    voidedAt: isVoided ? timestamp : null,
    createdAt: timestamp,
    updatedAt: timestamp,
    schemaVersion: FinancialTransaction.currentSchemaVersion,
  );
}
