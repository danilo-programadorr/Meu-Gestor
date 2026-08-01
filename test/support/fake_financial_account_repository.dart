import 'dart:async';

import 'package:meu_gestor_financeiro/features/accounts/domain/account_name.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';

final class FakeFinancialAccountRepository
    implements FinancialAccountRepository {
  FakeFinancialAccountRepository({List<FinancialAccount>? initialAccounts})
    : accounts = List<FinancialAccount>.of(
        initialAccounts ?? <FinancialAccount>[],
      );

  final List<FinancialAccount> accounts;
  FinancialAccountFailure? nextFailure;
  Completer<void>? readBarrier;
  Completer<void>? mutationBarrier;
  bool serverConfirmed = true;
  bool pendingWrites = false;
  int readCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int archiveCalls = 0;
  int generatedIdCalls = 0;

  @override
  String newAccountId({required String ownerId}) {
    generatedIdCalls += 1;
    return 'generated-$generatedIdCalls';
  }

  @override
  Future<FinancialAccount> create({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  }) async {
    createCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final FinancialAccountDraft normalized = draft.normalized();
    for (final FinancialAccount existing in accounts) {
      if (existing.id == accountId) {
        if (existing.name == normalized.name &&
            existing.type == normalized.type &&
            existing.openingBalanceCents == normalized.openingBalanceCents &&
            existing.includeInTotal == normalized.includeInTotal) {
          return existing;
        }
        throw const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.alreadyExists,
          safeMessage: 'Esta conta já existe.',
        );
      }
    }
    final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
    final FinancialAccount account = FinancialAccount(
      id: accountId,
      ownerId: ownerId,
      name: normalized.name,
      type: normalized.type,
      openingBalanceCents: normalized.openingBalanceCents,
      currencyCode: FinancialAccount.supportedCurrencyCode,
      includeInTotal: normalized.includeInTotal,
      isArchived: false,
      archivedAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: FinancialAccount.currentSchemaVersion,
    );
    accounts.add(account);
    return account;
  }

  @override
  Future<FinancialAccountsReadResult> readOwnAccounts({
    required String ownerId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    final Completer<void>? barrier = readBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    _throwIfNeeded();
    return FinancialAccountsReadResult(
      accounts: accounts
          .where((FinancialAccount account) => account.ownerId == ownerId)
          .toList(growable: false),
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<FinancialAccount> readOwnAccount({
    required String ownerId,
    required String accountId,
    required bool serverOnly,
  }) async {
    _throwIfNeeded();
    return accounts.firstWhere(
      (FinancialAccount account) =>
          account.ownerId == ownerId && account.id == accountId,
      orElse: () => throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.notFound,
        safeMessage: 'Esta conta não foi encontrada.',
      ),
    );
  }

  @override
  Future<FinancialAccount> setArchived({
    required String ownerId,
    required String accountId,
    required bool archived,
  }) async {
    archiveCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, accountId);
    final FinancialAccount current = accounts[index];
    final DateTime timestamp = current.updatedAt.add(
      const Duration(seconds: 1),
    );
    final FinancialAccount updated = current.copyWith(
      isArchived: archived,
      archivedAt: archived ? timestamp : null,
      clearArchivedAt: !archived,
      updatedAt: timestamp,
    );
    accounts[index] = updated;
    return updated;
  }

  @override
  Future<FinancialAccount> update({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  }) async {
    updateCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, accountId);
    final FinancialAccountDraft normalized = draft.normalized();
    final FinancialAccount current = accounts[index];
    final FinancialAccount updated = current.copyWith(
      name: AccountName.requireValid(normalized.name),
      type: normalized.type,
      openingBalanceCents: normalized.openingBalanceCents,
      includeInTotal: normalized.includeInTotal,
      updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    );
    accounts[index] = updated;
    return updated;
  }

  int _index(String ownerId, String accountId) {
    final int index = accounts.indexWhere(
      (FinancialAccount account) =>
          account.ownerId == ownerId && account.id == accountId,
    );
    if (index < 0) {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.notFound,
        safeMessage: 'Esta conta não foi encontrada.',
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
    final FinancialAccountFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }
}
