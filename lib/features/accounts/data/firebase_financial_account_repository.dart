import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firestore_financial_account_mapper.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';

final class FirebaseFinancialAccountRepository
    implements FinancialAccountRepository {
  FirebaseFinancialAccountRepository({
    required FirebaseFirestore firestore,
    required FinancialAccountDiagnostics diagnostics,
  }) : _firestore = firestore,
       _diagnostics = diagnostics;

  final FirebaseFirestore _firestore;
  final FinancialAccountDiagnostics _diagnostics;

  @override
  String newAccountId({required String ownerId}) => _accounts(ownerId).doc().id;

  @override
  Future<FinancialAccountsReadResult> readOwnAccounts({
    required String ownerId,
    required bool serverOnly,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _accounts(
        ownerId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      return decodeQuerySnapshot(
        ownerId: ownerId,
        documents: snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                  AccountDocumentData(id: document.id, data: document.data()),
            )
            .toList(growable: false),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_accounts',
        stage: serverOnly ? 'server_read' : 'default_read',
        error: error,
      );
    }
  }

  @visibleForTesting
  static FinancialAccountsReadResult decodeQuerySnapshot({
    required String ownerId,
    required List<AccountDocumentData> documents,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    final List<FinancialAccount> accounts =
        documents
            .map(
              (AccountDocumentData document) =>
                  FirestoreFinancialAccountMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                  ),
            )
            .toList(growable: false)
          ..sort(
            (FinancialAccount first, FinancialAccount second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
    return FinancialAccountsReadResult(
      accounts: List<FinancialAccount>.unmodifiable(accounts),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  Future<FinancialAccount> readOwnAccount({
    required String ownerId,
    required String accountId,
    required bool serverOnly,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _document(
        ownerId,
        accountId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.notFound,
          safeMessage: 'Esta conta não foi encontrada.',
          code: 'account_not_found',
        );
      }
      if (serverOnly &&
          (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites)) {
        throw const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.failedPrecondition,
          safeMessage:
              'A alteração ainda não foi confirmada. Verifique sua conexão e tente novamente.',
          code: 'account_not_server_confirmed',
        );
      }
      return FirestoreFinancialAccountMapper.fromMap(
        data: data,
        documentId: accountId,
        expectedOwnerId: ownerId,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_account',
        stage: serverOnly ? 'server_read' : 'default_read',
        error: error,
      );
    }
  }

  @override
  Future<FinancialAccount> create({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  }) async {
    final FinancialAccountDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      accountId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        if (snapshot.exists) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null) {
            throw const FinancialAccountFailure(
              kind: FinancialAccountFailureKind.incompatible,
              safeMessage: 'Não foi possível confirmar esta conta.',
              code: 'existing_account_without_data',
            );
          }
          final FinancialAccount existing =
              FirestoreFinancialAccountMapper.fromMap(
                data: data,
                documentId: accountId,
                expectedOwnerId: ownerId,
              );
          if (!FirestoreFinancialAccountMapper.matchesDraft(
            existing,
            normalized,
          )) {
            throw const FinancialAccountFailure(
              kind: FinancialAccountFailureKind.alreadyExists,
              safeMessage:
                  'Esta tentativa já possui uma conta diferente. Volte e tente novamente.',
              code: 'account_id_conflict',
            );
          }
          return;
        }
        transaction.set(
          reference,
          FirestoreFinancialAccountMapper.creationMap(
            ownerId: ownerId,
            draft: normalized,
          ),
        );
      });
      return _readConfirmed(ownerId, accountId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final FinancialAccount? confirmed = await _tryConfirmCreated(
          ownerId: ownerId,
          accountId: accountId,
          draft: normalized,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: 'create_account',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  @override
  Future<FinancialAccount> update({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  }) async {
    final FinancialAccountDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      accountId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        final Map<String, dynamic>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const FinancialAccountFailure(
            kind: FinancialAccountFailureKind.notFound,
            safeMessage: 'Esta conta não foi encontrada.',
            code: 'account_not_found',
          );
        }
        FirestoreFinancialAccountMapper.fromMap(
          data: data,
          documentId: accountId,
          expectedOwnerId: ownerId,
        );
        transaction.update(
          reference,
          FirestoreFinancialAccountMapper.editableMap(normalized),
        );
      });
      return _readConfirmed(ownerId, accountId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'update_account',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  @override
  Future<FinancialAccount> setArchived({
    required String ownerId,
    required String accountId,
    required bool archived,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      accountId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        final Map<String, dynamic>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const FinancialAccountFailure(
            kind: FinancialAccountFailureKind.notFound,
            safeMessage: 'Esta conta não foi encontrada.',
            code: 'account_not_found',
          );
        }
        final FinancialAccount current =
            FirestoreFinancialAccountMapper.fromMap(
              data: data,
              documentId: accountId,
              expectedOwnerId: ownerId,
            );
        if (current.isArchived == archived) {
          return;
        }
        transaction.update(reference, <String, Object?>{
          'isArchived': archived,
          'archivedAt': archived ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return _readConfirmed(ownerId, accountId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: archived ? 'archive_account' : 'restore_account',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  Future<FinancialAccount> _readConfirmed(String ownerId, String accountId) =>
      readOwnAccount(ownerId: ownerId, accountId: accountId, serverOnly: true);

  Future<FinancialAccount?> _tryConfirmCreated({
    required String ownerId,
    required String accountId,
    required FinancialAccountDraft draft,
  }) async {
    try {
      final FinancialAccount account = await _readConfirmed(ownerId, accountId);
      return FirestoreFinancialAccountMapper.matchesDraft(account, draft)
          ? account
          : null;
    } on Object {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _accounts(String ownerId) {
    if (ownerId.isEmpty) {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_owner_id',
      );
    }
    return _firestore.collection('users').doc(ownerId).collection('accounts');
  }

  DocumentReference<Map<String, dynamic>> _document(
    String ownerId,
    String accountId,
  ) {
    if (accountId.isEmpty || accountId.contains('/')) {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.validation,
        safeMessage: 'A conta informada não é válida.',
        code: 'invalid_account_id',
      );
    }
    return _accounts(ownerId).doc(accountId);
  }

  FinancialAccountFailure _mapAndRecord({
    required String operation,
    required String stage,
    required Object error,
  }) {
    final FinancialAccountFailure failure = mapFailure(error);
    _diagnostics.record(
      operation: operation,
      stage: stage,
      category: failure.kind.name,
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  @visibleForTesting
  static FinancialAccountFailure mapFailure(Object error) {
    if (error is FinancialAccountFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.permissionDenied,
          safeMessage: 'Não foi possível acessar suas contas com segurança.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.unavailable,
          safeMessage:
              'Suas contas estão temporariamente indisponíveis. Tente novamente.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.timeout,
          safeMessage: 'A operação demorou demais. Tente novamente.',
          code: 'deadline-exceeded',
        ),
        'aborted' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.aborted,
          safeMessage: 'A conta foi alterada em outro lugar. Tente novamente.',
          code: 'aborted',
        ),
        'failed-precondition' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.failedPrecondition,
          safeMessage: 'Não foi possível confirmar a alteração com segurança.',
          code: 'failed-precondition',
        ),
        'not-found' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.notFound,
          safeMessage: 'Esta conta não foi encontrada.',
          code: 'not-found',
        ),
        'already-exists' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.alreadyExists,
          safeMessage: 'Esta conta já existe.',
          code: 'already-exists',
        ),
        'data-loss' => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.dataLoss,
          safeMessage: 'Encontramos uma inconsistência nesta conta.',
          code: 'data-loss',
        ),
        _ => const FinancialAccountFailure(
          kind: FinancialAccountFailureKind.unknown,
          safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const FinancialAccountFailure(
      kind: FinancialAccountFailureKind.unknown,
      safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      code: 'unknown_account_error',
    );
  }

  static bool _isUncertain(Object error) => switch (mapFailure(error).kind) {
    FinancialAccountFailureKind.unavailable ||
    FinancialAccountFailureKind.timeout ||
    FinancialAccountFailureKind.aborted => true,
    _ => false,
  };
}

final class AccountDocumentData {
  const AccountDocumentData({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
