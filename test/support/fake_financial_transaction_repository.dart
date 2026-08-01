import 'dart:async';

import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_repository.dart';

final class FakeFinancialTransactionRepository
    implements FinancialTransactionRepository {
  FakeFinancialTransactionRepository({
    List<FinancialTransaction>? initialTransactions,
  }) : transactions = List<FinancialTransaction>.of(
         initialTransactions ?? <FinancialTransaction>[],
       );

  final List<FinancialTransaction> transactions;
  FinancialTransactionFailure? nextFailure;
  Completer<void>? mutationBarrier;
  bool serverConfirmed = true;
  bool pendingWrites = false;
  int readCalls = 0;
  int createCalls = 0;
  int generatedIdCalls = 0;

  @override
  String newTransactionId({required String ownerId}) {
    generatedIdCalls += 1;
    return 'generated-$generatedIdCalls';
  }

  @override
  Future<FinancialTransaction> create({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionDraft draft,
  }) async {
    createCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final DateTime now = DateTime.utc(2026, 8, 5, 12);
    final FinancialTransactionDraft normalized = draft.normalized(now: now);
    final FinancialTransaction? existing = _find(ownerId, transactionId);
    if (existing != null) {
      return existing;
    }
    final FinancialTransaction transaction = FinancialTransaction(
      id: transactionId,
      ownerId: ownerId,
      accountId: normalized.accountId,
      categoryId: normalized.categoryId,
      kind: normalized.kind,
      description: normalized.description,
      amountCents: normalized.amountCents,
      occurredAt: normalized.occurredAt,
      notes: normalized.notes,
      isVoided: false,
      voidedAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: FinancialTransaction.currentSchemaVersion,
    );
    transactions.add(transaction);
    return transaction;
  }

  @override
  Future<FinancialTransactionsReadResult> readOwnTransactions({
    required String ownerId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    _throwIfNeeded();
    return FinancialTransactionsReadResult(
      transactions: transactions
          .where((item) => item.ownerId == ownerId)
          .toList(growable: false),
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<FinancialTransaction> readOwnTransaction({
    required String ownerId,
    required String transactionId,
    required bool serverOnly,
  }) async =>
      _find(ownerId, transactionId) ??
      (throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.notFound,
        safeMessage: 'Lançamento não encontrado.',
      ));

  @override
  Future<FinancialTransaction> updateDescription({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionEdit edit,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, transactionId);
    final FinancialTransaction current = transactions[index];
    if (current.isVoided) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.voided,
        safeMessage: 'Lançamento cancelado não pode ser alterado.',
      );
    }
    final FinancialTransactionEdit normalized = edit.normalized(
      now: DateTime.utc(2026, 8, 5, 12),
    );
    transactions[index] = current.copyWith(
      categoryId: normalized.categoryId,
      description: normalized.description,
      occurredAt: normalized.occurredAt,
      notes: normalized.notes,
      updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    );
    return transactions[index];
  }

  @override
  Future<FinancialTransaction> voidTransaction({
    required String ownerId,
    required String transactionId,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, transactionId);
    final FinancialTransaction current = transactions[index];
    if (current.isVoided) {
      return current;
    }
    final DateTime timestamp = current.updatedAt.add(
      const Duration(seconds: 1),
    );
    transactions[index] = current.copyWith(
      isVoided: true,
      voidedAt: timestamp,
      updatedAt: timestamp,
    );
    return transactions[index];
  }

  FinancialTransaction? _find(String ownerId, String transactionId) {
    for (final FinancialTransaction transaction in transactions) {
      if (transaction.ownerId == ownerId && transaction.id == transactionId) {
        return transaction;
      }
    }
    return null;
  }

  int _index(String ownerId, String transactionId) {
    final int index = transactions.indexWhere(
      (item) => item.ownerId == ownerId && item.id == transactionId,
    );
    if (index < 0) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.notFound,
        safeMessage: 'Lançamento não encontrado.',
      );
    }
    return index;
  }

  Future<void> _waitMutation() async {
    final Completer<void>? barrier = mutationBarrier;
    if (barrier != null) {
      await barrier.future;
    }
  }

  void _throwIfNeeded() {
    final FinancialTransactionFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }
}
