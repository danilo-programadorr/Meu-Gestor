import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';

FinancialAccount createTestAccount({
  String id = 'account-1',
  String ownerId = 'owner',
  String name = 'Conta principal',
  FinancialAccountType type = FinancialAccountType.checking,
  int openingBalanceCents = 100000,
  bool includeInTotal = true,
  bool isArchived = false,
}) {
  final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
  return FinancialAccount(
    id: id,
    ownerId: ownerId,
    name: name,
    type: type,
    openingBalanceCents: openingBalanceCents,
    currencyCode: FinancialAccount.supportedCurrencyCode,
    includeInTotal: includeInTotal,
    isArchived: isArchived,
    archivedAt: isArchived ? timestamp : null,
    createdAt: timestamp,
    updatedAt: timestamp,
    schemaVersion: FinancialAccount.currentSchemaVersion,
  );
}
