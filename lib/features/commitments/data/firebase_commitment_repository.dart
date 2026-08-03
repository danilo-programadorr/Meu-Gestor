import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firestore_financial_account_mapper.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/data/firestore_financial_category_mapper.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/financial_commitment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_commitment_mapper_support.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_payable_mapper.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firestore_receivable_mapper.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/firestore_financial_transaction_mapper.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

final class FirebaseCommitmentRepository
    implements FinancialCommitmentRepository {
  FirebaseCommitmentRepository({
    required FirebaseFirestore firestore,
    required FinancialCommitmentDiagnostics diagnostics,
    required DateTime Function() now,
  }) : _firestore = firestore,
       _diagnostics = diagnostics,
       _now = now;

  final FirebaseFirestore _firestore;
  final FinancialCommitmentDiagnostics _diagnostics;
  final DateTime Function() _now;

  @override
  String newPayableId({required String ownerId}) =>
      _collection(ownerId, _CommitmentType.payable).doc().id;

  @override
  String newReceivableId({required String ownerId}) =>
      _collection(ownerId, _CommitmentType.receivable).doc().id;

  @override
  String newLinkedTransactionId({required String ownerId}) =>
      _transactions(ownerId).doc().id;

  @override
  Future<FinancialCommitmentsReadResult<Payable>> readOwnPayables({
    required String ownerId,
    required bool serverOnly,
  }) async {
    final _ReadResult result = await _readAll(
      ownerId: ownerId,
      type: _CommitmentType.payable,
      serverOnly: serverOnly,
    );
    return FinancialCommitmentsReadResult<Payable>(
      commitments: result.items.cast<Payable>(),
      isFromServer: result.isFromServer,
      hasPendingWrites: result.hasPendingWrites,
    );
  }

  @override
  Future<FinancialCommitmentsReadResult<Receivable>> readOwnReceivables({
    required String ownerId,
    required bool serverOnly,
  }) async {
    final _ReadResult result = await _readAll(
      ownerId: ownerId,
      type: _CommitmentType.receivable,
      serverOnly: serverOnly,
    );
    return FinancialCommitmentsReadResult<Receivable>(
      commitments: result.items.cast<Receivable>(),
      isFromServer: result.isFromServer,
      hasPendingWrites: result.hasPendingWrites,
    );
  }

  @override
  Future<Payable> readOwnPayable({
    required String ownerId,
    required String payableId,
    required bool serverOnly,
  }) async =>
      (await _readOne(
            ownerId: ownerId,
            id: payableId,
            type: _CommitmentType.payable,
            serverOnly: serverOnly,
          ))
          as Payable;

  @override
  Future<Receivable> readOwnReceivable({
    required String ownerId,
    required String receivableId,
    required bool serverOnly,
  }) async =>
      (await _readOne(
            ownerId: ownerId,
            id: receivableId,
            type: _CommitmentType.receivable,
            serverOnly: serverOnly,
          ))
          as Receivable;

  @override
  Future<Payable> createPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentDraft draft,
  }) async =>
      (await _create(
            ownerId: ownerId,
            id: payableId,
            type: _CommitmentType.payable,
            draft: draft,
          ))
          as Payable;

  @override
  Future<Receivable> createReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentDraft draft,
  }) async =>
      (await _create(
            ownerId: ownerId,
            id: receivableId,
            type: _CommitmentType.receivable,
            draft: draft,
          ))
          as Receivable;

  @override
  Future<Payable> updatePendingPayable({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentUpdate update,
  }) async =>
      (await _updatePending(
            ownerId: ownerId,
            id: payableId,
            type: _CommitmentType.payable,
            update: update,
          ))
          as Payable;

  @override
  Future<Receivable> updatePendingReceivable({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentUpdate update,
  }) async =>
      (await _updatePending(
            ownerId: ownerId,
            id: receivableId,
            type: _CommitmentType.receivable,
            update: update,
          ))
          as Receivable;

  @override
  Future<FinancialCommitmentMutationResult<Payable>> pay({
    required String ownerId,
    required String payableId,
    required FinancialCommitmentSettlementCommand command,
  }) async {
    final _MutationPair pair = await _settle(
      ownerId: ownerId,
      id: payableId,
      type: _CommitmentType.payable,
      command: command,
    );
    return FinancialCommitmentMutationResult<Payable>(
      commitment: pair.commitment as Payable,
      linkedTransaction: pair.transaction,
    );
  }

  @override
  Future<FinancialCommitmentMutationResult<Receivable>> receive({
    required String ownerId,
    required String receivableId,
    required FinancialCommitmentSettlementCommand command,
  }) async {
    final _MutationPair pair = await _settle(
      ownerId: ownerId,
      id: receivableId,
      type: _CommitmentType.receivable,
      command: command,
    );
    return FinancialCommitmentMutationResult<Receivable>(
      commitment: pair.commitment as Receivable,
      linkedTransaction: pair.transaction,
    );
  }

  @override
  Future<Payable> cancelPendingPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  }) async =>
      (await _cancelPending(
            ownerId: ownerId,
            id: payableId,
            type: _CommitmentType.payable,
            expectedRevision: expectedRevision,
          ))
          as Payable;

  @override
  Future<Receivable> cancelPendingReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  }) async =>
      (await _cancelPending(
            ownerId: ownerId,
            id: receivableId,
            type: _CommitmentType.receivable,
            expectedRevision: expectedRevision,
          ))
          as Receivable;

  @override
  Future<FinancialCommitmentMutationResult<Payable>> voidPaidPayable({
    required String ownerId,
    required String payableId,
    required int expectedRevision,
  }) async {
    final _MutationPair pair = await _voidSettlement(
      ownerId: ownerId,
      id: payableId,
      type: _CommitmentType.payable,
      expectedRevision: expectedRevision,
    );
    return FinancialCommitmentMutationResult<Payable>(
      commitment: pair.commitment as Payable,
      linkedTransaction: pair.transaction,
    );
  }

  @override
  Future<FinancialCommitmentMutationResult<Receivable>> voidReceivedReceivable({
    required String ownerId,
    required String receivableId,
    required int expectedRevision,
  }) async {
    final _MutationPair pair = await _voidSettlement(
      ownerId: ownerId,
      id: receivableId,
      type: _CommitmentType.receivable,
      expectedRevision: expectedRevision,
    );
    return FinancialCommitmentMutationResult<Receivable>(
      commitment: pair.commitment as Receivable,
      linkedTransaction: pair.transaction,
    );
  }

  Future<_ReadResult> _readAll({
    required String ownerId,
    required _CommitmentType type,
    required bool serverOnly,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection(
        ownerId,
        type,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      final SaoPauloCivilDate today = _today();
      final List<FinancialCommitment> commitments =
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                    _decode(
                      type: type,
                      data: document.data(),
                      id: document.id,
                      ownerId: ownerId,
                      today: today,
                    ),
              )
              .toList(growable: false)
            ..sort(_compareCommitments);
      return _ReadResult(
        items: List<FinancialCommitment>.unmodifiable(commitments),
        isFromServer: !snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_${type.collection}',
        stage: serverOnly ? 'server_read' : 'default_read',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<FinancialCommitment> _readOne({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required bool serverOnly,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _document(
        ownerId,
        type,
        id,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      if (serverOnly &&
          (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites)) {
        throw _failure(
          FinancialCommitmentFailureKind.failedPrecondition,
          'commitment_not_server_confirmed',
          'A alteração ainda não foi confirmada. Verifique sua conexão e tente novamente.',
        );
      }
      return _decodeSnapshot(
        snapshot: snapshot,
        ownerId: ownerId,
        id: id,
        type: type,
        today: _today(),
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_${type.singular}',
        stage: serverOnly ? 'server_read' : 'default_read',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<FinancialCommitment> _create({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required FinancialCommitmentDraft draft,
  }) async {
    final FinancialCommitmentDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      type,
      id,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final DocumentSnapshot<Map<String, dynamic>> existing = await operation
            .get(reference);
        if (existing.exists) {
          final FinancialCommitment current = _decodeSnapshot(
            snapshot: existing,
            ownerId: ownerId,
            id: id,
            type: type,
            today: _today(),
          );
          if (!FirestoreCommitmentMapperSupport.matchesDraft(
            current,
            normalized,
          )) {
            throw _failure(
              FinancialCommitmentFailureKind.alreadyExists,
              'commitment_id_conflict',
              'Esta tentativa já possui um compromisso diferente.',
            );
          }
          return;
        }
        final FinancialCategory category = _decodeCategory(
          snapshot: await operation.get(
            _category(ownerId, normalized.categoryId),
          ),
          ownerId: ownerId,
          categoryId: normalized.categoryId,
        );
        _validateCategory(category, type.transactionKind);
        operation.set(
          reference,
          type == _CommitmentType.payable
              ? FirestorePayableMapper.creationMap(
                  ownerId: ownerId,
                  draft: normalized,
                )
              : FirestoreReceivableMapper.creationMap(
                  ownerId: ownerId,
                  draft: normalized,
                ),
        );
      });
      return _readOne(ownerId: ownerId, id: id, type: type, serverOnly: true);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final FinancialCommitment? confirmed = await _tryConfirmCreated(
          ownerId: ownerId,
          id: id,
          type: type,
          draft: normalized,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: 'create_${type.singular}',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<FinancialCommitment> _updatePending({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required FinancialCommitmentUpdate update,
  }) async {
    final FinancialCommitmentUpdate normalized = update.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      type,
      id,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final FinancialCommitment current = _decodeSnapshot(
          snapshot: await operation.get(reference),
          ownerId: ownerId,
          id: id,
          type: type,
          today: _today(),
        );
        _requirePendingRevision(current, normalized.expectedRevision);
        final FinancialCategory category = _decodeCategory(
          snapshot: await operation.get(
            _category(ownerId, normalized.categoryId),
          ),
          ownerId: ownerId,
          categoryId: normalized.categoryId,
        );
        _validateCategory(category, type.transactionKind);
        operation.update(
          reference,
          FirestoreCommitmentMapperSupport.editableMap(normalized),
        );
      });
      return _readOne(ownerId: ownerId, id: id, type: type, serverOnly: true);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'update_${type.singular}',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<_MutationPair> _settle({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required FinancialCommitmentSettlementCommand command,
  }) async {
    final SaoPauloCivilDate today = _today();
    final FinancialCommitmentSettlementCommand normalized = command.normalized(
      today: today,
    );
    final DocumentReference<Map<String, dynamic>> commitmentReference =
        _document(ownerId, type, id);
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final String
      linkedTransactionId = await _firestore.runTransaction<String>((
        Transaction operation,
      ) async {
        final FinancialCommitment current = _decodeSnapshot(
          snapshot: await operation.get(commitmentReference),
          ownerId: ownerId,
          id: id,
          type: type,
          today: today,
        );
        if (current.isSettled) {
          final String existingId = current.linkedTransactionId!;
          final FinancialTransaction transaction = _decodeRequiredTransaction(
            snapshot: await operation.get(_transaction(ownerId, existingId)),
            ownerId: ownerId,
            transactionId: existingId,
          );
          validateSettledPair(
            commitment: current,
            transaction: transaction,
            expectedAccountId: normalized.accountId,
            expectedMovementDate: normalized.movementDate,
          );
          return existingId;
        }
        _requirePendingRevision(current, normalized.expectedRevision);

        final DocumentReference<Map<String, dynamic>> transactionReference =
            _transaction(ownerId, normalized.transactionId);
        final DocumentSnapshot<Map<String, dynamic>> accountSnapshot =
            await operation.get(_account(ownerId, normalized.accountId));
        final DocumentSnapshot<Map<String, dynamic>> categorySnapshot =
            await operation.get(_category(ownerId, current.categoryId));
        final DocumentSnapshot<Map<String, dynamic>> transactionSnapshot =
            await operation.get(transactionReference);
        if (transactionSnapshot.exists) {
          throw _failure(
            FinancialCommitmentFailureKind.conflict,
            'linked_transaction_id_conflict',
            'A tentativa de liquidação entrou em conflito. Tente novamente.',
          );
        }
        final FinancialAccount account = _decodeAccount(
          snapshot: accountSnapshot,
          ownerId: ownerId,
          accountId: normalized.accountId,
        );
        final FinancialCategory category = _decodeCategory(
          snapshot: categorySnapshot,
          ownerId: ownerId,
          categoryId: current.categoryId,
        );
        _validateSettlementReferences(
          account: account,
          category: category,
          kind: type.transactionKind,
        );
        final FinancialTransactionDraft transactionDraft =
            FinancialTransactionDraft(
              accountId: normalized.accountId,
              categoryId: current.categoryId,
              kind: type.transactionKind,
              description: current.description,
              amountCents: current.amountCents,
              occurredAt: normalized.movementDate.toStorageInstant(),
              notes: current.notes,
            );
        operation.set(
          transactionReference,
          FirestoreFinancialTransactionMapper.creationMap(
            ownerId: ownerId,
            draft: transactionDraft,
            now: _now().toUtc(),
            originType: type.originType,
            originId: id,
          ),
        );
        operation.update(
          commitmentReference,
          FirestoreCommitmentMapperSupport.settlementMap(
            settledStatus: type.settledStatus,
            movementField: type.movementField,
            command: normalized,
          ),
        );
        return normalized.transactionId;
      });
      return _readConfirmedPair(
        ownerId: ownerId,
        id: id,
        type: type,
        transactionId: linkedTransactionId,
      );
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final _MutationPair? confirmed = await _tryReadPair(
          ownerId: ownerId,
          id: id,
          type: type,
          requireVoided: false,
          expectedAccountId: normalized.accountId,
          expectedMovementDate: normalized.movementDate,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: type == _CommitmentType.payable ? 'pay' : 'receive',
        stage: 'atomic_transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<FinancialCommitment> _cancelPending({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required int expectedRevision,
  }) async {
    if (expectedRevision < 1) {
      throw _failure(
        FinancialCommitmentFailureKind.validation,
        'invalid_expected_revision',
        'A versão do compromisso é inválida.',
      );
    }
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      type,
      id,
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      await _firestore.runTransaction<void>((Transaction operation) async {
        final FinancialCommitment current = _decodeSnapshot(
          snapshot: await operation.get(reference),
          ownerId: ownerId,
          id: id,
          type: type,
          today: _today(),
        );
        if (current.isCancelled) {
          return;
        }
        _requirePendingRevision(current, expectedRevision);
        operation.update(
          reference,
          FirestoreCommitmentMapperSupport.cancellationMap(expectedRevision),
        );
      });
      return _readOne(ownerId: ownerId, id: id, type: type, serverOnly: true);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        try {
          final FinancialCommitment current = await _readOne(
            ownerId: ownerId,
            id: id,
            type: type,
            serverOnly: true,
          );
          if (current.isCancelled) {
            return current;
          }
        } on Object {
          // A falha original preserva o estado incerto para uma nova tentativa.
        }
      }
      throw _mapAndRecord(
        operation: 'cancel_${type.singular}',
        stage: 'transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<_MutationPair> _voidSettlement({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required int expectedRevision,
  }) async {
    if (expectedRevision < 1) {
      throw _failure(
        FinancialCommitmentFailureKind.validation,
        'invalid_expected_revision',
        'A versão do compromisso é inválida.',
      );
    }
    final DocumentReference<Map<String, dynamic>> commitmentReference =
        _document(ownerId, type, id);
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final String linkedTransactionId = await _firestore
          .runTransaction<String>((Transaction operation) async {
            final FinancialCommitment current = _decodeSnapshot(
              snapshot: await operation.get(commitmentReference),
              ownerId: ownerId,
              id: id,
              type: type,
              today: _today(),
            );
            if (!current.isSettled && !current.isVoided) {
              throw _failure(
                FinancialCommitmentFailureKind.invalidState,
                'commitment_not_settled',
                'Somente uma liquidação confirmada pode ser anulada.',
              );
            }
            final String transactionId = current.linkedTransactionId!;
            final DocumentReference<Map<String, dynamic>> transactionReference =
                _transaction(ownerId, transactionId);
            final FinancialTransaction transaction = _decodeRequiredTransaction(
              snapshot: await operation.get(transactionReference),
              ownerId: ownerId,
              transactionId: transactionId,
            );
            validateSettledPair(
              commitment: current,
              transaction: transaction,
              expectedAccountId: current.settlementAccountId!,
              expectedMovementDate: current.movementDate!,
              allowVoided: current.isVoided,
            );
            if (current.isVoided) {
              if (!transaction.isVoided) {
                throw _failure(
                  FinancialCommitmentFailureKind.incompatible,
                  'voided_commitment_with_active_transaction',
                  'A anulação está inconsistente e não foi alterada.',
                );
              }
              return transactionId;
            }
            if (current.revision != expectedRevision) {
              throw _revisionConflict();
            }
            if (transaction.isVoided) {
              throw _failure(
                FinancialCommitmentFailureKind.incompatible,
                'settled_commitment_with_voided_transaction',
                'A liquidação está inconsistente e não foi alterada.',
              );
            }
            operation.update(transactionReference, <String, Object>{
              'isVoided': true,
              'voidedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            operation.update(
              commitmentReference,
              FirestoreCommitmentMapperSupport.voidMap(expectedRevision),
            );
            return transactionId;
          });
      return _readConfirmedPair(
        ownerId: ownerId,
        id: id,
        type: type,
        transactionId: linkedTransactionId,
      );
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final _MutationPair? confirmed = await _tryReadPair(
          ownerId: ownerId,
          id: id,
          type: type,
          requireVoided: true,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: 'void_${type.singular}',
        stage: 'atomic_transaction_or_confirmation',
        stopwatch: stopwatch,
        error: error,
      );
    }
  }

  Future<_MutationPair> _readConfirmedPair({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required String transactionId,
  }) async {
    final FinancialCommitment commitment = await _readOne(
      ownerId: ownerId,
      id: id,
      type: type,
      serverOnly: true,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _transaction(
      ownerId,
      transactionId,
    ).get(const GetOptions(source: Source.server));
    if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw _failure(
        FinancialCommitmentFailureKind.failedPrecondition,
        'linked_transaction_not_server_confirmed',
        'A alteração ainda não foi confirmada. Tente novamente.',
      );
    }
    final FinancialTransaction transaction = _decodeRequiredTransaction(
      snapshot: snapshot,
      ownerId: ownerId,
      transactionId: transactionId,
    );
    validateSettledPair(
      commitment: commitment,
      transaction: transaction,
      expectedAccountId: commitment.settlementAccountId!,
      expectedMovementDate: commitment.movementDate!,
      allowVoided: commitment.isVoided,
    );
    return _MutationPair(commitment: commitment, transaction: transaction);
  }

  Future<_MutationPair?> _tryReadPair({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required bool requireVoided,
    String? expectedAccountId,
    SaoPauloCivilDate? expectedMovementDate,
  }) async {
    try {
      final FinancialCommitment commitment = await _readOne(
        ownerId: ownerId,
        id: id,
        type: type,
        serverOnly: true,
      );
      if (requireVoided ? !commitment.isVoided : !commitment.isSettled) {
        return null;
      }
      final _MutationPair pair = await _readConfirmedPair(
        ownerId: ownerId,
        id: id,
        type: type,
        transactionId: commitment.linkedTransactionId!,
      );
      if (expectedAccountId != null &&
          pair.transaction.accountId != expectedAccountId) {
        return null;
      }
      if (expectedMovementDate != null &&
          pair.commitment.movementDate != expectedMovementDate) {
        return null;
      }
      return pair;
    } on Object {
      return null;
    }
  }

  Future<FinancialCommitment?> _tryConfirmCreated({
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required FinancialCommitmentDraft draft,
  }) async {
    try {
      final FinancialCommitment commitment = await _readOne(
        ownerId: ownerId,
        id: id,
        type: type,
        serverOnly: true,
      );
      return FirestoreCommitmentMapperSupport.matchesDraft(commitment, draft)
          ? commitment
          : null;
    } on Object {
      return null;
    }
  }

  @visibleForTesting
  static void validateSettledPair({
    required FinancialCommitment commitment,
    required FinancialTransaction transaction,
    required String expectedAccountId,
    required SaoPauloCivilDate expectedMovementDate,
    bool allowVoided = false,
  }) {
    final FinancialTransactionOriginType expectedOrigin =
        commitment.kind == FinancialCommitmentKind.payable
        ? FinancialTransactionOriginType.payable
        : FinancialTransactionOriginType.receivable;
    final FinancialTransactionKind expectedKind =
        commitment.kind == FinancialCommitmentKind.payable
        ? FinancialTransactionKind.expense
        : FinancialTransactionKind.income;
    if (commitment.linkedTransactionId != transaction.id ||
        commitment.settlementAccountId != expectedAccountId ||
        commitment.movementDate != expectedMovementDate ||
        transaction.ownerId != commitment.ownerId ||
        transaction.accountId != expectedAccountId ||
        transaction.categoryId != commitment.categoryId ||
        transaction.kind != expectedKind ||
        transaction.amountCents != commitment.amountCents ||
        transaction.occurredAt != expectedMovementDate.toStorageInstant() ||
        transaction.schemaVersion != FinancialTransaction.linkedSchemaVersion ||
        transaction.originType != expectedOrigin ||
        transaction.originId != commitment.id ||
        (!allowVoided && transaction.isVoided)) {
      throw _failure(
        FinancialCommitmentFailureKind.incompatible,
        'commitment_transaction_mismatch',
        'A liquidação está inconsistente e nenhum dado foi alterado.',
      );
    }
  }

  FinancialCommitment _decodeSnapshot({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String id,
    required _CommitmentType type,
    required SaoPauloCivilDate today,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw _failure(
        FinancialCommitmentFailureKind.notFound,
        'commitment_not_found',
        'Este compromisso não foi encontrado.',
      );
    }
    return _decode(
      type: type,
      data: data,
      id: id,
      ownerId: ownerId,
      today: today,
    );
  }

  FinancialCommitment _decode({
    required _CommitmentType type,
    required Map<String, dynamic> data,
    required String id,
    required String ownerId,
    required SaoPauloCivilDate today,
  }) => type == _CommitmentType.payable
      ? FirestorePayableMapper.fromMap(
          data: data,
          documentId: id,
          expectedOwnerId: ownerId,
          today: today,
        )
      : FirestoreReceivableMapper.fromMap(
          data: data,
          documentId: id,
          expectedOwnerId: ownerId,
          today: today,
        );

  FinancialAccount _decodeAccount({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String accountId,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw _failure(
        FinancialCommitmentFailureKind.notFound,
        'settlement_account_not_found',
        'A conta selecionada não está disponível.',
      );
    }
    try {
      return FirestoreFinancialAccountMapper.fromMap(
        data: data,
        documentId: accountId,
        expectedOwnerId: ownerId,
      );
    } on Object {
      throw _failure(
        FinancialCommitmentFailureKind.incompatible,
        'settlement_account_invalid',
        'A conta selecionada não está disponível.',
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
      throw _failure(
        FinancialCommitmentFailureKind.notFound,
        'commitment_category_not_found',
        'A categoria selecionada não está disponível.',
      );
    }
    try {
      return FirestoreFinancialCategoryMapper.fromMap(
        data: data,
        documentId: categoryId,
        expectedOwnerId: ownerId,
      );
    } on Object {
      throw _failure(
        FinancialCommitmentFailureKind.incompatible,
        'commitment_category_invalid',
        'A categoria selecionada não está disponível.',
      );
    }
  }

  FinancialTransaction _decodeRequiredTransaction({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String transactionId,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw _failure(
        FinancialCommitmentFailureKind.incompatible,
        'linked_transaction_not_found',
        'O lançamento vinculado não foi encontrado.',
      );
    }
    try {
      return FirestoreFinancialTransactionMapper.fromMap(
        data: data,
        documentId: transactionId,
        expectedOwnerId: ownerId,
        now: _now().toUtc(),
      );
    } on Object {
      throw _failure(
        FinancialCommitmentFailureKind.incompatible,
        'linked_transaction_invalid',
        'O lançamento vinculado está inconsistente.',
      );
    }
  }

  static void _validateSettlementReferences({
    required FinancialAccount account,
    required FinancialCategory category,
    required FinancialTransactionKind kind,
  }) {
    if (account.isArchived) {
      throw _failure(
        FinancialCommitmentFailureKind.failedPrecondition,
        'settlement_account_archived',
        'A conta selecionada não está disponível.',
      );
    }
    _validateCategory(category, kind);
  }

  static void _validateCategory(
    FinancialCategory category,
    FinancialTransactionKind kind,
  ) {
    if (category.isArchived || category.kind != kind.categoryKind) {
      throw _failure(
        FinancialCommitmentFailureKind.failedPrecondition,
        'commitment_category_unavailable',
        'A categoria selecionada não está disponível para este compromisso.',
      );
    }
  }

  static void _requirePendingRevision(
    FinancialCommitment commitment,
    int expectedRevision,
  ) {
    if (!commitment.isPending) {
      throw _failure(
        FinancialCommitmentFailureKind.invalidState,
        'commitment_not_pending',
        'Este compromisso não está mais pendente.',
      );
    }
    if (commitment.revision != expectedRevision) {
      throw _revisionConflict();
    }
  }

  static FinancialCommitmentFailure _revisionConflict() => _failure(
    FinancialCommitmentFailureKind.conflict,
    'commitment_revision_conflict',
    'O compromisso foi alterado em outro lugar. Atualize e tente novamente.',
  );

  SaoPauloCivilDate _today() => SaoPauloCivilDate.fromInstant(_now().toUtc());

  CollectionReference<Map<String, dynamic>> _collection(
    String ownerId,
    _CommitmentType type,
  ) {
    _requireOwnerId(ownerId);
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection(type.collection);
  }

  CollectionReference<Map<String, dynamic>> _transactions(String ownerId) {
    _requireOwnerId(ownerId);
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('transactions');
  }

  DocumentReference<Map<String, dynamic>> _document(
    String ownerId,
    _CommitmentType type,
    String id,
  ) {
    _requireDocumentId(id, label: 'compromisso');
    return _collection(ownerId, type).doc(id);
  }

  DocumentReference<Map<String, dynamic>> _transaction(
    String ownerId,
    String id,
  ) {
    _requireDocumentId(id, label: 'lançamento');
    return _transactions(ownerId).doc(id);
  }

  DocumentReference<Map<String, dynamic>> _account(String ownerId, String id) =>
      _firestore
          .collection('users')
          .doc(ownerId)
          .collection('accounts')
          .doc(id);

  DocumentReference<Map<String, dynamic>> _category(
    String ownerId,
    String id,
  ) => _firestore
      .collection('users')
      .doc(ownerId)
      .collection('categories')
      .doc(id);

  static void _requireOwnerId(String ownerId) {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw _failure(
        FinancialCommitmentFailureKind.unauthenticated,
        'missing_owner_id',
        'Sua sessão não está disponível. Entre novamente.',
      );
    }
  }

  static void _requireDocumentId(String id, {required String label}) {
    if (id.isEmpty || id.length > 150 || id.contains('/')) {
      throw _failure(
        FinancialCommitmentFailureKind.validation,
        'invalid_commitment_reference',
        'A referência de $label é inválida.',
      );
    }
  }

  FinancialCommitmentFailure _mapAndRecord({
    required String operation,
    required String stage,
    required Stopwatch stopwatch,
    required Object error,
  }) {
    stopwatch.stop();
    final FinancialCommitmentFailure failure = mapFailure(error);
    _diagnostics.record(
      operation: operation,
      stage: stage,
      duration: stopwatch.elapsed,
      category: failure.kind.name,
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  @visibleForTesting
  static FinancialCommitmentFailure mapFailure(Object error) {
    if (error is FinancialCommitmentFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => _failure(
          FinancialCommitmentFailureKind.permissionDenied,
          'permission-denied',
          'Não foi possível acessar seus compromissos com segurança.',
        ),
        'unauthenticated' => _failure(
          FinancialCommitmentFailureKind.unauthenticated,
          'unauthenticated',
          'Sua sessão não está disponível. Entre novamente.',
        ),
        'unavailable' => _failure(
          FinancialCommitmentFailureKind.unavailable,
          'unavailable',
          'Verifique sua conexão e tente novamente.',
        ),
        'deadline-exceeded' => _failure(
          FinancialCommitmentFailureKind.timeout,
          'deadline-exceeded',
          'A operação demorou demais. Tente novamente.',
        ),
        'aborted' => _failure(
          FinancialCommitmentFailureKind.conflict,
          'aborted',
          'O compromisso foi alterado em outro lugar. Tente novamente.',
        ),
        'failed-precondition' => _failure(
          FinancialCommitmentFailureKind.failedPrecondition,
          'failed-precondition',
          'Não foi possível confirmar a alteração com segurança.',
        ),
        'not-found' => _failure(
          FinancialCommitmentFailureKind.notFound,
          'not-found',
          'Este compromisso não foi encontrado.',
        ),
        'already-exists' => _failure(
          FinancialCommitmentFailureKind.alreadyExists,
          'already-exists',
          'Este compromisso já existe.',
        ),
        'data-loss' => _failure(
          FinancialCommitmentFailureKind.dataLoss,
          'data-loss',
          'Encontramos uma inconsistência neste compromisso.',
        ),
        _ => _failure(
          FinancialCommitmentFailureKind.unknown,
          'unknown_firestore_error',
          'Não foi possível concluir a operação. Tente novamente.',
        ),
      };
    }
    return _failure(
      FinancialCommitmentFailureKind.unknown,
      'unknown_commitment_error',
      'Não foi possível concluir a operação. Tente novamente.',
    );
  }

  static bool _isUncertain(Object error) => switch (mapFailure(error).kind) {
    FinancialCommitmentFailureKind.unavailable ||
    FinancialCommitmentFailureKind.timeout ||
    FinancialCommitmentFailureKind.conflict => true,
    _ => false,
  };

  static int _compareCommitments(
    FinancialCommitment first,
    FinancialCommitment second,
  ) {
    final int byDueDate = first.dueDate.compareTo(second.dueDate);
    if (byDueDate != 0) {
      return byDueDate;
    }
    final int byCreated = second.createdAt.compareTo(first.createdAt);
    return byCreated != 0 ? byCreated : first.id.compareTo(second.id);
  }
}

enum _CommitmentType {
  payable,
  receivable;

  String get collection => this == payable ? 'payables' : 'receivables';
  String get singular => this == payable ? 'payable' : 'receivable';
  String get settledStatus => this == payable ? 'paid' : 'received';
  String get movementField => this == payable ? 'paidAt' : 'receivedAt';
  FinancialTransactionKind get transactionKind => this == payable
      ? FinancialTransactionKind.expense
      : FinancialTransactionKind.income;
  FinancialTransactionOriginType get originType => this == payable
      ? FinancialTransactionOriginType.payable
      : FinancialTransactionOriginType.receivable;
}

final class _ReadResult {
  const _ReadResult({
    required this.items,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<FinancialCommitment> items;
  final bool isFromServer;
  final bool hasPendingWrites;
}

final class _MutationPair {
  const _MutationPair({required this.commitment, required this.transaction});

  final FinancialCommitment commitment;
  final FinancialTransaction transaction;
}

FinancialCommitmentFailure _failure(
  FinancialCommitmentFailureKind kind,
  String code,
  String message,
) => FinancialCommitmentFailure(kind: kind, safeMessage: message, code: code);
