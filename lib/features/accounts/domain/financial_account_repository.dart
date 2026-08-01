import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';

final class FinancialAccountsReadResult {
  const FinancialAccountsReadResult({
    required this.accounts,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<FinancialAccount> accounts;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class FinancialAccountRepository {
  String newAccountId({required String ownerId});

  Future<FinancialAccountsReadResult> readOwnAccounts({
    required String ownerId,
    required bool serverOnly,
  });

  Future<FinancialAccount> readOwnAccount({
    required String ownerId,
    required String accountId,
    required bool serverOnly,
  });

  Future<FinancialAccount> create({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  });

  Future<FinancialAccount> update({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  });

  Future<FinancialAccount> setArchived({
    required String ownerId,
    required String accountId,
    required bool archived,
  });
}
