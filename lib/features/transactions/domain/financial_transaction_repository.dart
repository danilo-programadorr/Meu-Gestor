import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

final class FinancialTransactionsReadResult {
  const FinancialTransactionsReadResult({
    required this.transactions,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<FinancialTransaction> transactions;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class FinancialTransactionRepository {
  String newTransactionId({required String ownerId});

  Future<FinancialTransactionsReadResult> readOwnTransactions({
    required String ownerId,
    required bool serverOnly,
  });

  Future<FinancialTransaction> readOwnTransaction({
    required String ownerId,
    required String transactionId,
    required bool serverOnly,
  });

  Future<FinancialTransaction> create({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionDraft draft,
  });

  Future<FinancialTransaction> updateDescription({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionEdit edit,
  });

  Future<FinancialTransaction> voidTransaction({
    required String ownerId,
    required String transactionId,
  });
}
