import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firestore_financial_account_mapper.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/data/firestore_financial_category_mapper.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/firestore_financial_transaction_mapper.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_repository.dart';

final class FirebaseFinancialTransactionRepository
    implements FinancialTransactionRepository {
  FirebaseFinancialTransactionRepository({
    required FirebaseFirestore firestore,
    required FinancialTransactionDiagnostics diagnostics,
    required DateTime Function() now,
  }) : _firestore = firestore,
       _diagnostics = diagnostics,
       _now = now;

  final FirebaseFirestore _firestore;
  final FinancialTransactionDiagnostics _diagnostics;
  final DateTime Function() _now;

  @override
  String newTransactionId({required String ownerId}) =>
      _transactions(ownerId).doc().id;

  @override
  Future<FinancialTransactionsReadResult> readOwnTransactions({
    required String ownerId,
    required bool serverOnly,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _transactions(
        ownerId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      return decodeQuerySnapshot(
        ownerId: ownerId,
        documents: snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                  TransactionDocumentData(
                    id: document.id,
                    data: document.data(),
                  ),
            )
            .toList(growable: false),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        now: _now(),
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_transactions',
        stage: serverOnly ? 'server_read' : 'default_read',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  @visibleForTesting
  static FinancialTransactionsReadResult decodeQuerySnapshot({
    required String ownerId,
    required List<TransactionDocumentData> documents,
    required bool isFromCache,
    required bool hasPendingWrites,
    required DateTime now,
  }) {
    final List<FinancialTransaction> transactions =
        documents
            .map(
              (TransactionDocumentData document) =>
                  FirestoreFinancialTransactionMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                    now: now,
                  ),
            )
            .toList(growable: false)
          ..sort(_compareTransactions);
    return FinancialTransactionsReadResult(
      transactions: List<FinancialTransaction>.unmodifiable(transactions),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  static int _compareTransactions(
    FinancialTransaction first,
    FinancialTransaction second,
  ) {
    final int byDate = second.occurredAt.compareTo(first.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    final int byCreated = second.createdAt.compareTo(first.createdAt);
    return byCreated != 0 ? byCreated : first.id.compareTo(second.id);
  }

  @override
  Future<FinancialTransaction> readOwnTransaction({
    required String ownerId,
    required String transactionId,
    required bool serverOnly,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _document(
        ownerId,
        transactionId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.notFound,
          safeMessage: 'Este lançamento não foi encontrado.',
          code: 'transaction_not_found',
        );
      }
      if (serverOnly &&
          (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites)) {
        throw const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.failedPrecondition,
          safeMessage:
              'A alteração ainda não foi confirmada. Verifique sua conexão e tente novamente.',
          code: 'transaction_not_server_confirmed',
        );
      }
      return FirestoreFinancialTransactionMapper.fromMap(
        data: data,
        documentId: transactionId,
        expectedOwnerId: ownerId,
        now: _now(),
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_transaction',
        stage: serverOnly ? 'server_read' : 'default_read',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  @override
  Future<FinancialTransaction> create({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionDraft draft,
  }) async {
    final DateTime now = _now().toUtc();
    final FinancialTransactionDraft normalized = draft.normalized(now: now);
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      transactionId,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final DocumentSnapshot<Map<String, dynamic>> existing = await operation
            .get(reference);
        if (existing.exists) {
          final FinancialTransaction current = _decodeRequiredTransaction(
            snapshot: existing,
            ownerId: ownerId,
            transactionId: transactionId,
            now: now,
          );
          if (!FirestoreFinancialTransactionMapper.matchesDraft(
            current,
            normalized,
            now: now,
          )) {
            throw const FinancialTransactionFailure(
              kind: FinancialTransactionFailureKind.alreadyExists,
              safeMessage:
                  'Esta tentativa já possui um lançamento diferente. Volte e tente novamente.',
              code: 'transaction_id_conflict',
            );
          }
          return;
        }
        final DocumentReference<Map<String, dynamic>> accountReference =
            _firestore
                .collection('users')
                .doc(ownerId)
                .collection('accounts')
                .doc(normalized.accountId);
        final DocumentReference<Map<String, dynamic>> categoryReference =
            _firestore
                .collection('users')
                .doc(ownerId)
                .collection('categories')
                .doc(normalized.categoryId);
        final DocumentSnapshot<Map<String, dynamic>> accountSnapshot =
            await operation.get(accountReference);
        final DocumentSnapshot<Map<String, dynamic>> categorySnapshot =
            await operation.get(categoryReference);
        final FinancialAccount account = _decodeAccount(
          snapshot: accountSnapshot,
          ownerId: ownerId,
          accountId: normalized.accountId,
        );
        final FinancialCategory category = _decodeCategory(
          snapshot: categorySnapshot,
          ownerId: ownerId,
          categoryId: normalized.categoryId,
        );
        _validateReferences(
          account: account,
          category: category,
          kind: normalized.kind,
        );
        operation.set(
          reference,
          FirestoreFinancialTransactionMapper.creationMap(
            ownerId: ownerId,
            draft: normalized,
            now: now,
          ),
        );
      });
      return _readConfirmed(ownerId, transactionId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final FinancialTransaction? confirmed = await _tryConfirmCreated(
          ownerId: ownerId,
          transactionId: transactionId,
          draft: normalized,
          now: now,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: 'create_transaction',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  @override
  Future<FinancialTransaction> updateDescription({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionEdit edit,
  }) async {
    final DateTime now = _now().toUtc();
    final FinancialTransactionEdit normalized = edit.normalized(now: now);
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      transactionId,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await operation
            .get(reference);
        final FinancialTransaction current = _decodeRequiredTransaction(
          snapshot: snapshot,
          ownerId: ownerId,
          transactionId: transactionId,
          now: now,
        );
        if (current.isVoided) {
          throw const FinancialTransactionFailure(
            kind: FinancialTransactionFailureKind.voided,
            safeMessage: 'Um lançamento cancelado não pode ser editado.',
            code: 'transaction_already_voided',
          );
        }
        final DocumentReference<Map<String, dynamic>> categoryReference =
            _firestore
                .collection('users')
                .doc(ownerId)
                .collection('categories')
                .doc(normalized.categoryId);
        final DocumentSnapshot<Map<String, dynamic>> categorySnapshot =
            await operation.get(categoryReference);
        final FinancialCategory category = _decodeCategory(
          snapshot: categorySnapshot,
          ownerId: ownerId,
          categoryId: normalized.categoryId,
        );
        _validateCategory(category, current.kind);
        operation.update(
          reference,
          FirestoreFinancialTransactionMapper.editableMap(
            edit: normalized,
            now: now,
          ),
        );
      });
      return _readConfirmed(ownerId, transactionId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'update_transaction',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  @override
  Future<FinancialTransaction> voidTransaction({
    required String ownerId,
    required String transactionId,
  }) async {
    final DateTime now = _now().toUtc();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      transactionId,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await operation
            .get(reference);
        final FinancialTransaction current = _decodeRequiredTransaction(
          snapshot: snapshot,
          ownerId: ownerId,
          transactionId: transactionId,
          now: now,
        );
        if (current.isVoided) {
          throw const FinancialTransactionFailure(
            kind: FinancialTransactionFailureKind.voided,
            safeMessage: 'Este lançamento já está cancelado.',
            code: 'transaction_already_voided',
          );
        }
        operation.update(reference, <String, Object>{
          'isVoided': true,
          'voidedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return _readConfirmed(ownerId, transactionId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'void_transaction',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  FinancialAccount _decodeAccount({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String accountId,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.notFound,
        safeMessage:
            'A conta selecionada não está disponível para novos lançamentos.',
        code: 'transaction_account_not_found',
      );
    }
    try {
      return FirestoreFinancialAccountMapper.fromMap(
        data: data,
        documentId: accountId,
        expectedOwnerId: ownerId,
      );
    } on Object {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.incompatible,
        safeMessage:
            'A conta selecionada não está disponível para novos lançamentos.',
        code: 'transaction_account_invalid',
      );
    }
  }

  FinancialCategory _decodeCategory({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String categoryId,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.notFound,
        safeMessage: 'A categoria selecionada não está disponível.',
        code: 'transaction_category_not_found',
      );
    }
    try {
      return FirestoreFinancialCategoryMapper.fromMap(
        data: data,
        documentId: categoryId,
        expectedOwnerId: ownerId,
      );
    } on Object {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.incompatible,
        safeMessage: 'A categoria selecionada não está disponível.',
        code: 'transaction_category_invalid',
      );
    }
  }

  FinancialTransaction _decodeRequiredTransaction({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String transactionId,
    required DateTime now,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.notFound,
        safeMessage: 'Este lançamento não foi encontrado.',
        code: 'transaction_not_found',
      );
    }
    return FirestoreFinancialTransactionMapper.fromMap(
      data: data,
      documentId: transactionId,
      expectedOwnerId: ownerId,
      now: now,
    );
  }

  static void _validateReferences({
    required FinancialAccount account,
    required FinancialCategory category,
    required FinancialTransactionKind kind,
  }) {
    if (account.isArchived) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.accountArchived,
        safeMessage:
            'A conta selecionada não está disponível para novos lançamentos.',
        code: 'transaction_account_archived',
      );
    }
    _validateCategory(category, kind);
  }

  static void _validateCategory(
    FinancialCategory category,
    FinancialTransactionKind kind,
  ) {
    if (category.isArchived) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.categoryArchived,
        safeMessage: 'A categoria selecionada não está disponível.',
        code: 'transaction_category_archived',
      );
    }
    if (category.kind != kind.categoryKind) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.categoryMismatch,
        safeMessage:
            'Escolha uma categoria compatível com o tipo do lançamento.',
        code: 'transaction_category_mismatch',
      );
    }
  }

  Future<FinancialTransaction> _readConfirmed(
    String ownerId,
    String transactionId,
  ) => readOwnTransaction(
    ownerId: ownerId,
    transactionId: transactionId,
    serverOnly: true,
  );

  Future<FinancialTransaction?> _tryConfirmCreated({
    required String ownerId,
    required String transactionId,
    required FinancialTransactionDraft draft,
    required DateTime now,
  }) async {
    try {
      final FinancialTransaction transaction = await _readConfirmed(
        ownerId,
        transactionId,
      );
      return FirestoreFinancialTransactionMapper.matchesDraft(
            transaction,
            draft,
            now: now,
          )
          ? transaction
          : null;
    } on Object {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _transactions(String ownerId) {
    if (ownerId.isEmpty) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_owner_id',
      );
    }
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('transactions');
  }

  DocumentReference<Map<String, dynamic>> _document(
    String ownerId,
    String transactionId,
  ) {
    if (transactionId.isEmpty || transactionId.contains('/')) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.validation,
        safeMessage: 'O lançamento informado não é válido.',
        code: 'invalid_transaction_id',
      );
    }
    return _transactions(ownerId).doc(transactionId);
  }

  FinancialTransactionFailure _mapAndRecord({
    required String operation,
    required String stage,
    required Stopwatch stopwatch,
    required Object error,
  }) {
    stopwatch.stop();
    final FinancialTransactionFailure failure = mapFailure(error);
    _diagnostics.record(
      operation: operation,
      stage: stage,
      duration: stopwatch.elapsed,
      category: failure.kind.name,
      finalState: 'failure',
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  @visibleForTesting
  static FinancialTransactionFailure mapFailure(Object error) {
    if (error is FinancialTransactionFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.permissionDenied,
          safeMessage:
              'Não foi possível acessar seus lançamentos com segurança.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.unavailable,
          safeMessage: 'Verifique sua conexão e tente novamente.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.timeout,
          safeMessage: 'A operação demorou demais. Tente novamente.',
          code: 'deadline-exceeded',
        ),
        'aborted' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.aborted,
          safeMessage:
              'O lançamento foi alterado em outro lugar. Tente novamente.',
          code: 'aborted',
        ),
        'failed-precondition' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.failedPrecondition,
          safeMessage: 'Não foi possível confirmar a alteração com segurança.',
          code: 'failed-precondition',
        ),
        'not-found' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.notFound,
          safeMessage: 'Este lançamento não foi encontrado.',
          code: 'not-found',
        ),
        'already-exists' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.alreadyExists,
          safeMessage: 'Este lançamento já existe.',
          code: 'already-exists',
        ),
        'data-loss' => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.dataLoss,
          safeMessage: 'Encontramos uma inconsistência neste lançamento.',
          code: 'data-loss',
        ),
        _ => const FinancialTransactionFailure(
          kind: FinancialTransactionFailureKind.unknown,
          safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const FinancialTransactionFailure(
      kind: FinancialTransactionFailureKind.unknown,
      safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      code: 'unknown_transaction_error',
    );
  }

  static bool _isUncertain(Object error) => switch (mapFailure(error).kind) {
    FinancialTransactionFailureKind.unavailable ||
    FinancialTransactionFailureKind.timeout ||
    FinancialTransactionFailureKind.aborted ||
    FinancialTransactionFailureKind.uncertain => true,
    _ => false,
  };
}

final class TransactionDocumentData {
  const TransactionDocumentData({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
