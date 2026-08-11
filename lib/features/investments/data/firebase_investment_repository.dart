import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firestore_investment_mappers.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class FirebaseInvestmentRepository implements InvestmentRepository {
  FirebaseInvestmentRepository({
    required FirebaseFirestore firestore,
    required InvestmentDiagnostics diagnostics,
    required DateTime Function() now,
  }) : _firestore = firestore,
       _diagnostics = diagnostics,
       _now = now;

  static const Duration _timeout = Duration(seconds: 12);

  final FirebaseFirestore _firestore;
  final InvestmentDiagnostics _diagnostics;
  final DateTime Function() _now;

  @override
  String newPortfolioId({required String ownerId}) =>
      _portfolios(ownerId).doc().id;

  @override
  String newOperationId({required String ownerId}) =>
      _operations(ownerId).doc().id;

  @override
  String newIncomeEventId({required String ownerId}) =>
      _incomeEvents(ownerId).doc().id;

  @override
  String newMutationId({required String ownerId}) =>
      _operations(ownerId).doc().id;

  @override
  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
    bool includeIncome = true,
  }) async {
    try {
      final GetOptions? options = serverOnly
          ? const GetOptions(source: Source.server)
          : null;
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> reads =
          <Future<QuerySnapshot<Map<String, dynamic>>>>[
            _portfolios(ownerId).get(options),
            _assets(ownerId).get(options),
            _operations(ownerId).get(options),
            if (includeIncome) _incomeEvents(ownerId).get(options),
          ];
      final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
          await Future.wait<QuerySnapshot<Map<String, dynamic>>>(
            reads,
          ).timeout(_timeout);
      return decodeWorkspace(
        ownerId: ownerId,
        portfolioDocuments: _documents(snapshots[0]),
        assetDocuments: _documents(snapshots[1]),
        operationDocuments: _documents(snapshots[2]),
        incomeDocuments: includeIncome
            ? _documents(snapshots[3])
            : const <InvestmentDocumentData>[],
        isFromCache: snapshots.any(
          (QuerySnapshot<Map<String, dynamic>> value) =>
              value.metadata.isFromCache,
        ),
        hasPendingWrites: snapshots.any(
          (QuerySnapshot<Map<String, dynamic>> value) =>
              value.metadata.hasPendingWrites,
        ),
        now: _now(),
      );
    } on Object catch (error) {
      throw _mapAndRecord('read_investment_workspace', 'server_read', error);
    }
  }

  @visibleForTesting
  static InvestmentWorkspaceReadResult decodeWorkspace({
    required String ownerId,
    required List<InvestmentDocumentData> portfolioDocuments,
    required List<InvestmentDocumentData> assetDocuments,
    required List<InvestmentDocumentData> operationDocuments,
    List<InvestmentDocumentData> incomeDocuments =
        const <InvestmentDocumentData>[],
    required bool isFromCache,
    required bool hasPendingWrites,
    required DateTime now,
  }) {
    final List<InvestmentPortfolio> portfolios =
        portfolioDocuments
            .map(
              (InvestmentDocumentData document) =>
                  FirestoreInvestmentPortfolioMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                  ),
            )
            .toList(growable: false)
          ..sort(
            (InvestmentPortfolio first, InvestmentPortfolio second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
    final List<TrackedInvestmentAsset> assets =
        assetDocuments
            .map(
              (InvestmentDocumentData document) =>
                  FirestoreTrackedInvestmentAssetMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                  ),
            )
            .toList(growable: false)
          ..sort(
            (TrackedInvestmentAsset first, TrackedInvestmentAsset second) =>
                first.ticker.compareTo(second.ticker),
          );
    final List<InvestmentOperation> operations =
        operationDocuments
            .map(
              (InvestmentDocumentData document) =>
                  FirestoreInvestmentOperationMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                    now: now,
                  ),
            )
            .toList(growable: false)
          ..sort(_compareOperations);
    final List<InvestmentIncomeEvent> incomeEvents =
        incomeDocuments
            .map(
              (InvestmentDocumentData document) =>
                  FirestoreInvestmentIncomeEventMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                    now: now,
                  ),
            )
            .toList(growable: false)
          ..sort(_compareIncomeEvents);
    return InvestmentWorkspaceReadResult(
      portfolios: List<InvestmentPortfolio>.unmodifiable(portfolios),
      assets: List<TrackedInvestmentAsset>.unmodifiable(assets),
      operations: List<InvestmentOperation>.unmodifiable(operations),
      incomeEvents: List<InvestmentIncomeEvent>.unmodifiable(incomeEvents),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  Future<InvestmentPortfolio> createPortfolio({
    required String ownerId,
    required String portfolioId,
    required InvestmentPortfolioDraft draft,
  }) async {
    final InvestmentPortfolioDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _portfolios(
      ownerId,
    ).doc(portfolioId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final DocumentSnapshot<Map<String, dynamic>> snapshot =
                await transaction.get(reference);
            if (snapshot.exists) {
              final InvestmentPortfolio existing = _portfolioFromSnapshot(
                snapshot,
                ownerId,
              );
              if (!FirestoreInvestmentPortfolioMapper.matchesDraft(
                existing,
                normalized,
              )) {
                throw const InvestmentFailure(
                  kind: InvestmentFailureKind.alreadyExists,
                  safeMessage: 'Esta tentativa já possui outra carteira.',
                  code: 'investment_portfolio_id_conflict',
                );
              }
              return;
            }
            transaction.set(
              reference,
              FirestoreInvestmentPortfolioMapper.creationMap(
                ownerId: ownerId,
                draft: normalized,
              ),
            );
          })
          .timeout(_timeout);
      return _readPortfolio(ownerId, portfolioId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final InvestmentPortfolio? confirmed = await _tryReadPortfolio(
          ownerId,
          portfolioId,
        );
        if (confirmed != null &&
            FirestoreInvestmentPortfolioMapper.matchesDraft(
              confirmed,
              normalized,
            )) {
          return confirmed;
        }
      }
      throw _mapAndRecord('create_investment_portfolio', 'transaction', error);
    }
  }

  @override
  Future<InvestmentPortfolio> updatePortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required InvestmentPortfolioDraft draft,
  }) async {
    final InvestmentPortfolioDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _portfolios(
      ownerId,
    ).doc(portfolioId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentPortfolio current = _portfolioFromSnapshot(
              await transaction.get(reference),
              ownerId,
            );
            if (current.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            transaction.update(reference, <String, Object>{
              'name': normalized.name,
              'description': normalized.description,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': current.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readPortfolio(ownerId, portfolioId);
    } on Object catch (error) {
      throw _mapAndRecord('update_investment_portfolio', 'transaction', error);
    }
  }

  @override
  Future<InvestmentPortfolio> setPortfolioArchived({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required bool archived,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _portfolios(
      ownerId,
    ).doc(portfolioId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentPortfolio current = _portfolioFromSnapshot(
              await transaction.get(reference),
              ownerId,
            );
            if (current.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            if (current.isArchived == archived) {
              return;
            }
            transaction.update(reference, <String, Object?>{
              'isArchived': archived,
              'archivedAt': archived ? FieldValue.serverTimestamp() : null,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': current.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readPortfolio(ownerId, portfolioId);
    } on Object catch (error) {
      throw _mapAndRecord(
        archived
            ? 'archive_investment_portfolio'
            : 'restore_investment_portfolio',
        'transaction',
        error,
      );
    }
  }

  @override
  Future<TrackedInvestmentAsset> createAsset({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
  }) async {
    final TrackedInvestmentAssetDraft normalized = draft.normalized();
    final String assetId = TrackedInvestmentAsset.documentId(
      portfolioId: normalized.portfolioId,
      ticker: normalized.ticker,
    );
    final DocumentReference<Map<String, dynamic>> assetReference = _assets(
      ownerId,
    ).doc(assetId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentPortfolio portfolio = _portfolioFromSnapshot(
              await transaction.get(
                _portfolios(ownerId).doc(normalized.portfolioId),
              ),
              ownerId,
            );
            if (portfolio.isArchived) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'Restaure a carteira antes de adicionar ativos.',
                code: 'investment_portfolio_archived',
              );
            }
            final DocumentSnapshot<Map<String, dynamic>> existing =
                await transaction.get(assetReference);
            if (existing.exists) {
              final TrackedInvestmentAsset asset = _assetFromSnapshot(
                existing,
                ownerId,
              );
              if (asset.portfolioId == normalized.portfolioId &&
                  asset.ticker == normalized.ticker &&
                  asset.name == normalized.name &&
                  asset.type == normalized.type) {
                return;
              }
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.alreadyExists,
                safeMessage: 'Este ticker já existe nessa carteira.',
                code: 'investment_asset_already_exists',
              );
            }
            transaction.set(
              assetReference,
              FirestoreTrackedInvestmentAssetMapper.creationMap(
                ownerId: ownerId,
                draft: normalized,
              ),
            );
          })
          .timeout(_timeout);
      return _readAsset(ownerId, assetId);
    } on Object catch (error) {
      throw _mapAndRecord('create_investment_asset', 'transaction', error);
    }
  }

  @override
  Future<InvestmentOperation> createOperation({
    required String ownerId,
    required String operationId,
    required InvestmentOperationDraft draft,
  }) async {
    final InvestmentOperationDraft normalized = draft.normalized(now: _now());
    final DocumentReference<Map<String, dynamic>> operationReference =
        _operations(ownerId).doc(operationId);
    final DocumentReference<Map<String, dynamic>> assetReference = _assets(
      ownerId,
    ).doc(normalized.assetId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final DocumentSnapshot<Map<String, dynamic>> existing =
                await transaction.get(operationReference);
            if (existing.exists) {
              final InvestmentOperation operation = _operationFromSnapshot(
                existing,
                ownerId,
              );
              if (!FirestoreInvestmentOperationMapper.matchesDraft(
                operation,
                normalized,
              )) {
                throw const InvestmentFailure(
                  kind: InvestmentFailureKind.alreadyExists,
                  safeMessage: 'Esta tentativa já possui outra operação.',
                  code: 'investment_operation_id_conflict',
                );
              }
              return;
            }
            final InvestmentPortfolio portfolio = _portfolioFromSnapshot(
              await transaction.get(
                _portfolios(ownerId).doc(normalized.portfolioId),
              ),
              ownerId,
            );
            final TrackedInvestmentAsset asset = _assetFromSnapshot(
              await transaction.get(assetReference),
              ownerId,
            );
            if (portfolio.isArchived ||
                asset.portfolioId != portfolio.id ||
                asset.id != normalized.assetId) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'A carteira ou o ativo não está disponível.',
                code: 'investment_operation_reference_unavailable',
              );
            }
            if (asset.lastOperationAt != null &&
                normalized.occurredAt.isBefore(asset.lastOperationAt!)) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.chronologicalOrder,
                safeMessage:
                    'Registre as operações da mais antiga para a mais recente.',
                code: 'investment_operation_out_of_order',
              );
            }
            final int newQuantity =
                normalized.kind == InvestmentOperationKind.buy
                ? asset.currentQuantityScaled + normalized.quantityScaled
                : asset.currentQuantityScaled - normalized.quantityScaled;
            if (newQuantity < 0) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.insufficientPosition,
                safeMessage: 'A venda supera a quantidade disponível.',
                code: 'investment_sell_exceeds_position',
              );
            }
            if (newQuantity > InvestmentScale.maximumQuantityScaled) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.overflow,
                safeMessage:
                    'A quantidade ultrapassa o limite seguro. Nenhum dado foi alterado.',
                code: 'investment_quantity_projection_overflow',
              );
            }
            transaction.set(
              operationReference,
              FirestoreInvestmentOperationMapper.creationMap(
                ownerId: ownerId,
                operationId: operationId,
                draft: normalized,
                previousOperationId: asset.lastOperationId,
                previousOperationAt: asset.lastOperationAt,
              ),
            );
            transaction.update(assetReference, <String, Object?>{
              'currentQuantityScaled': newQuantity,
              'lastOperationId': operationId,
              'lastOperationAt': Timestamp.fromDate(normalized.occurredAt),
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': asset.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readOperation(ownerId, operationId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final InvestmentOperation? confirmed = await _tryReadOperation(
          ownerId,
          operationId,
        );
        if (confirmed != null &&
            FirestoreInvestmentOperationMapper.matchesDraft(
              confirmed,
              normalized,
            )) {
          return confirmed;
        }
      }
      throw _mapAndRecord('create_investment_operation', 'transaction', error);
    }
  }

  @override
  Future<InvestmentOperation> voidOperation({
    required String ownerId,
    required String operationId,
    required int expectedRevision,
    required String mutationId,
  }) async {
    if (mutationId.isEmpty || mutationId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Não foi possível identificar esta tentativa.',
        code: 'invalid_investment_mutation_id',
      );
    }
    final DocumentReference<Map<String, dynamic>> operationReference =
        _operations(ownerId).doc(operationId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentOperation operation = _operationFromSnapshot(
              await transaction.get(operationReference),
              ownerId,
            );
            if (operation.isVoided) {
              if (operation.mutationId == mutationId) {
                return;
              }
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'Esta operação já foi anulada.',
                code: 'investment_operation_already_voided',
              );
            }
            if (operation.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            final DocumentReference<Map<String, dynamic>> assetReference =
                _assets(ownerId).doc(operation.assetId);
            final TrackedInvestmentAsset asset = _assetFromSnapshot(
              await transaction.get(assetReference),
              ownerId,
            );
            if (asset.lastOperationId != operation.id) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.historicalCorrectionBlocked,
                safeMessage:
                    'Por segurança, anule primeiro as operações mais recentes deste ativo.',
                code: 'investment_void_not_latest_operation',
              );
            }
            final int newQuantity =
                operation.kind == InvestmentOperationKind.buy
                ? asset.currentQuantityScaled - operation.quantityScaled
                : asset.currentQuantityScaled + operation.quantityScaled;
            if (newQuantity < 0) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.historicalCorrectionBlocked,
                safeMessage: 'A anulação deixaria o histórico inconsistente.',
                code: 'investment_void_would_invalidate_history',
              );
            }
            transaction.update(operationReference, <String, Object?>{
              'isVoided': true,
              'voidedAt': FieldValue.serverTimestamp(),
              'mutationId': mutationId,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': operation.revision + 1,
            });
            transaction.update(assetReference, <String, Object?>{
              'currentQuantityScaled': newQuantity,
              'lastOperationId': operation.previousOperationId,
              'lastOperationAt': operation.previousOperationAt,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': asset.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readOperation(ownerId, operationId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final InvestmentOperation? confirmed = await _tryReadOperation(
          ownerId,
          operationId,
        );
        if (confirmed?.isVoided == true &&
            confirmed?.mutationId == mutationId) {
          return confirmed!;
        }
      }
      throw _mapAndRecord('void_investment_operation', 'transaction', error);
    }
  }

  @override
  Future<InvestmentIncomeEvent> createIncomeEvent({
    required String ownerId,
    required String eventId,
    required InvestmentIncomeDraft draft,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _incomeEvents(
      ownerId,
    ).doc(eventId);
    InvestmentIncomeDraft? normalized;
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final DocumentSnapshot<Map<String, dynamic>> existing =
                await transaction.get(reference);
            final TrackedInvestmentAsset asset = await _incomeAssetReference(
              transaction,
              ownerId: ownerId,
              portfolioId: draft.portfolioId,
              assetId: draft.assetId,
              requireActivePortfolio: true,
            );
            normalized = draft.normalized(assetType: asset.type);
            if (existing.exists) {
              final InvestmentIncomeEvent event = _incomeFromSnapshot(
                existing,
                ownerId,
              );
              if (!FirestoreInvestmentIncomeEventMapper.matchesDraft(
                    event,
                    normalized!,
                  ) ||
                  event.status != InvestmentIncomeStatus.expected ||
                  event.mutationId != eventId) {
                throw const InvestmentFailure(
                  kind: InvestmentFailureKind.alreadyExists,
                  safeMessage: 'Esta tentativa já possui outro provento.',
                  code: 'investment_income_id_conflict',
                );
              }
              return;
            }
            transaction.set(
              reference,
              FirestoreInvestmentIncomeEventMapper.creationMap(
                ownerId: ownerId,
                eventId: eventId,
                draft: normalized!,
              ),
            );
          })
          .timeout(_timeout);
      return _readIncomeEvent(ownerId, eventId);
    } on Object catch (error) {
      if (_isUncertain(error) && normalized != null) {
        final InvestmentIncomeEvent? confirmed = await _tryReadIncomeEvent(
          ownerId,
          eventId,
        );
        if (confirmed != null &&
            confirmed.status == InvestmentIncomeStatus.expected &&
            confirmed.mutationId == eventId &&
            FirestoreInvestmentIncomeEventMapper.matchesDraft(
              confirmed,
              normalized!,
            )) {
          return confirmed;
        }
      }
      throw _mapAndRecord('create_investment_income', 'transaction', error);
    }
  }

  @override
  Future<InvestmentIncomeEvent> updateExpectedIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeDraft draft,
  }) async {
    _requireMutationId(mutationId);
    final DocumentReference<Map<String, dynamic>> reference = _incomeEvents(
      ownerId,
    ).doc(eventId);
    InvestmentIncomeDraft? normalized;
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentIncomeEvent current = _incomeFromSnapshot(
              await transaction.get(reference),
              ownerId,
            );
            final TrackedInvestmentAsset asset = await _incomeAssetReference(
              transaction,
              ownerId: ownerId,
              portfolioId: current.portfolioId,
              assetId: current.assetId,
              requireActivePortfolio: true,
            );
            normalized = draft.normalized(assetType: asset.type);
            if (normalized!.portfolioId != current.portfolioId ||
                normalized!.assetId != current.assetId) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage:
                    'A carteira e o ativo de um provento não podem ser alterados.',
                code: 'investment_income_reference_immutable',
              );
            }
            if (current.status == InvestmentIncomeStatus.expected &&
                current.mutationId == mutationId &&
                FirestoreInvestmentIncomeEventMapper.matchesDraft(
                  current,
                  normalized!,
                )) {
              return;
            }
            if (current.status != InvestmentIncomeStatus.expected) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'Somente proventos previstos podem ser editados.',
                code: 'investment_income_not_editable',
              );
            }
            if (current.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            transaction.update(
              reference,
              FirestoreInvestmentIncomeEventMapper.expectedUpdateMap(
                draft: normalized!,
                mutationId: mutationId,
                revision: current.revision + 1,
              ),
            );
          })
          .timeout(_timeout);
      return _readIncomeEvent(ownerId, eventId);
    } on Object catch (error) {
      if (_isUncertain(error) && normalized != null) {
        final InvestmentIncomeEvent? confirmed = await _tryReadIncomeEvent(
          ownerId,
          eventId,
        );
        if (confirmed?.status == InvestmentIncomeStatus.expected &&
            confirmed?.mutationId == mutationId &&
            FirestoreInvestmentIncomeEventMapper.matchesDraft(
              confirmed!,
              normalized!,
            )) {
          return confirmed;
        }
      }
      throw _mapAndRecord('update_investment_income', 'transaction', error);
    }
  }

  @override
  Future<InvestmentIncomeEvent> receiveIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required DateTime receivedDate,
  }) async {
    _requireMutationId(mutationId);
    final DateTime normalizedDate = InvestmentIncomeEvent.normalizeCivilDate(
      receivedDate,
    );
    InvestmentIncomeEvent.validateReceivedDate(normalizedDate, now: _now());
    final DocumentReference<Map<String, dynamic>> reference = _incomeEvents(
      ownerId,
    ).doc(eventId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentIncomeEvent current = _incomeFromSnapshot(
              await transaction.get(reference),
              ownerId,
            );
            if (current.status == InvestmentIncomeStatus.received &&
                current.mutationId == mutationId &&
                current.receivedDate == normalizedDate) {
              return;
            }
            if (current.status != InvestmentIncomeStatus.expected) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'Este provento não pode ser confirmado.',
                code: 'investment_income_receive_transition_denied',
              );
            }
            if (current.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            final TrackedInvestmentAsset asset = await _incomeAssetReference(
              transaction,
              ownerId: ownerId,
              portfolioId: current.portfolioId,
              assetId: current.assetId,
              requireActivePortfolio: true,
            );
            if (!current.type.isCompatibleWith(asset.type)) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'O provento não é compatível com este ativo.',
                code: 'investment_income_asset_type_mismatch',
              );
            }
            transaction.update(reference, <String, Object?>{
              'status': InvestmentIncomeStatus.received.name,
              'receivedDate': Timestamp.fromDate(normalizedDate),
              'mutationId': mutationId,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': current.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readIncomeEvent(ownerId, eventId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final InvestmentIncomeEvent? confirmed = await _tryReadIncomeEvent(
          ownerId,
          eventId,
        );
        if (confirmed?.status == InvestmentIncomeStatus.received &&
            confirmed?.mutationId == mutationId &&
            confirmed?.receivedDate == normalizedDate) {
          return confirmed!;
        }
      }
      throw _mapAndRecord('receive_investment_income', 'transaction', error);
    }
  }

  @override
  Future<InvestmentIncomeEvent> cancelIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) => _terminalIncomeTransition(
    ownerId: ownerId,
    eventId: eventId,
    expectedRevision: expectedRevision,
    mutationId: mutationId,
    from: InvestmentIncomeStatus.expected,
    to: InvestmentIncomeStatus.cancelled,
    timestampField: 'cancelledAt',
    operationName: 'cancel_investment_income',
  );

  @override
  Future<InvestmentIncomeEvent> voidIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) => _terminalIncomeTransition(
    ownerId: ownerId,
    eventId: eventId,
    expectedRevision: expectedRevision,
    mutationId: mutationId,
    from: InvestmentIncomeStatus.received,
    to: InvestmentIncomeStatus.voided,
    timestampField: 'voidedAt',
    operationName: 'void_investment_income',
  );

  Future<InvestmentIncomeEvent> _terminalIncomeTransition({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeStatus from,
    required InvestmentIncomeStatus to,
    required String timestampField,
    required String operationName,
  }) async {
    _requireMutationId(mutationId);
    final DocumentReference<Map<String, dynamic>> reference = _incomeEvents(
      ownerId,
    ).doc(eventId);
    try {
      await _firestore
          .runTransaction<void>((Transaction transaction) async {
            final InvestmentIncomeEvent current = _incomeFromSnapshot(
              await transaction.get(reference),
              ownerId,
            );
            if (current.status == to && current.mutationId == mutationId) {
              return;
            }
            if (current.status != from || !current.canTransitionTo(to)) {
              throw const InvestmentFailure(
                kind: InvestmentFailureKind.failedPrecondition,
                safeMessage: 'Esta transição de provento não é permitida.',
                code: 'investment_income_transition_denied',
              );
            }
            if (current.revision != expectedRevision) {
              throw _concurrencyFailure();
            }
            transaction.update(reference, <String, Object?>{
              'status': to.name,
              timestampField: FieldValue.serverTimestamp(),
              'mutationId': mutationId,
              'updatedAt': FieldValue.serverTimestamp(),
              'revision': current.revision + 1,
            });
          })
          .timeout(_timeout);
      return _readIncomeEvent(ownerId, eventId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final InvestmentIncomeEvent? confirmed = await _tryReadIncomeEvent(
          ownerId,
          eventId,
        );
        if (confirmed?.status == to && confirmed?.mutationId == mutationId) {
          return confirmed!;
        }
      }
      throw _mapAndRecord(operationName, 'transaction', error);
    }
  }

  Future<InvestmentPortfolio> _readPortfolio(String ownerId, String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _portfolios(
      ownerId,
    ).doc(id).get(const GetOptions(source: Source.server)).timeout(_timeout);
    _requireConfirmed(snapshot);
    return _portfolioFromSnapshot(snapshot, ownerId);
  }

  Future<TrackedInvestmentAsset> _readAsset(String ownerId, String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _assets(
      ownerId,
    ).doc(id).get(const GetOptions(source: Source.server)).timeout(_timeout);
    _requireConfirmed(snapshot);
    return _assetFromSnapshot(snapshot, ownerId);
  }

  Future<InvestmentOperation> _readOperation(String ownerId, String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _operations(
      ownerId,
    ).doc(id).get(const GetOptions(source: Source.server)).timeout(_timeout);
    _requireConfirmed(snapshot);
    return _operationFromSnapshot(snapshot, ownerId);
  }

  Future<InvestmentIncomeEvent> _readIncomeEvent(
    String ownerId,
    String id,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _incomeEvents(
      ownerId,
    ).doc(id).get(const GetOptions(source: Source.server)).timeout(_timeout);
    _requireConfirmed(snapshot);
    return _incomeFromSnapshot(snapshot, ownerId);
  }

  Future<InvestmentPortfolio?> _tryReadPortfolio(
    String ownerId,
    String id,
  ) async {
    try {
      return await _readPortfolio(ownerId, id);
    } on Object {
      return null;
    }
  }

  Future<InvestmentOperation?> _tryReadOperation(
    String ownerId,
    String id,
  ) async {
    try {
      return await _readOperation(ownerId, id);
    } on Object {
      return null;
    }
  }

  Future<InvestmentIncomeEvent?> _tryReadIncomeEvent(
    String ownerId,
    String id,
  ) async {
    try {
      return await _readIncomeEvent(ownerId, id);
    } on Object {
      return null;
    }
  }

  Future<TrackedInvestmentAsset> _incomeAssetReference(
    Transaction transaction, {
    required String ownerId,
    required String portfolioId,
    required String assetId,
    required bool requireActivePortfolio,
  }) async {
    final InvestmentPortfolio portfolio = _portfolioFromSnapshot(
      await transaction.get(_portfolios(ownerId).doc(portfolioId)),
      ownerId,
    );
    final TrackedInvestmentAsset asset = _assetFromSnapshot(
      await transaction.get(_assets(ownerId).doc(assetId)),
      ownerId,
    );
    if ((requireActivePortfolio && portfolio.isArchived) ||
        asset.portfolioId != portfolio.id) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.failedPrecondition,
        safeMessage: 'A carteira ou o ativo não está disponível.',
        code: 'investment_income_reference_unavailable',
      );
    }
    return asset;
  }

  InvestmentPortfolio _portfolioFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String ownerId,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.notFound,
        safeMessage: 'Esta carteira não foi encontrada.',
        code: 'investment_portfolio_not_found',
      );
    }
    return FirestoreInvestmentPortfolioMapper.fromMap(
      data: data,
      documentId: snapshot.id,
      expectedOwnerId: ownerId,
    );
  }

  TrackedInvestmentAsset _assetFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String ownerId,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.notFound,
        safeMessage: 'Este ativo não foi encontrado.',
        code: 'investment_asset_not_found',
      );
    }
    return FirestoreTrackedInvestmentAssetMapper.fromMap(
      data: data,
      documentId: snapshot.id,
      expectedOwnerId: ownerId,
    );
  }

  InvestmentOperation _operationFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String ownerId,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.notFound,
        safeMessage: 'Esta operação não foi encontrada.',
        code: 'investment_operation_not_found',
      );
    }
    return FirestoreInvestmentOperationMapper.fromMap(
      data: data,
      documentId: snapshot.id,
      expectedOwnerId: ownerId,
      now: _now(),
    );
  }

  InvestmentIncomeEvent _incomeFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String ownerId,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.notFound,
        safeMessage: 'Este provento não foi encontrado.',
        code: 'investment_income_not_found',
      );
    }
    return FirestoreInvestmentIncomeEventMapper.fromMap(
      data: data,
      documentId: snapshot.id,
      expectedOwnerId: ownerId,
      now: _now(),
    );
  }

  static void _requireConfirmed(DocumentSnapshot<Map<String, dynamic>> value) {
    if (value.metadata.isFromCache || value.metadata.hasPendingWrites) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.failedPrecondition,
        safeMessage: 'A alteração ainda não foi confirmada pelo servidor.',
        code: 'investment_not_server_confirmed',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _portfolios(String ownerId) =>
      _user(ownerId).collection('investmentPortfolios');

  CollectionReference<Map<String, dynamic>> _assets(String ownerId) =>
      _user(ownerId).collection('investmentAssets');

  CollectionReference<Map<String, dynamic>> _operations(String ownerId) =>
      _user(ownerId).collection('investmentOperations');

  CollectionReference<Map<String, dynamic>> _incomeEvents(String ownerId) =>
      _user(ownerId).collection('investmentIncomeEvents');

  DocumentReference<Map<String, dynamic>> _user(String ownerId) {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_investment_owner',
      );
    }
    return _firestore.collection('users').doc(ownerId);
  }

  InvestmentFailure _mapAndRecord(
    String operation,
    String stage,
    Object error,
  ) {
    final InvestmentFailure failure = mapFailure(error);
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
  static InvestmentFailure mapFailure(Object error) {
    if (error is InvestmentFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const InvestmentFailure(
        kind: InvestmentFailureKind.timeout,
        safeMessage: 'A operação demorou demais. Tente novamente.',
        code: 'investment_timeout',
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const InvestmentFailure(
          kind: InvestmentFailureKind.permissionDenied,
          safeMessage:
              'Não foi possível acessar seus investimentos com segurança.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const InvestmentFailure(
          kind: InvestmentFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const InvestmentFailure(
          kind: InvestmentFailureKind.unavailable,
          safeMessage:
              'Seus investimentos estão temporariamente indisponíveis.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const InvestmentFailure(
          kind: InvestmentFailureKind.timeout,
          safeMessage: 'A operação demorou demais. Tente novamente.',
          code: 'deadline-exceeded',
        ),
        'aborted' => _concurrencyFailure(),
        'failed-precondition' => const InvestmentFailure(
          kind: InvestmentFailureKind.failedPrecondition,
          safeMessage: 'Não foi possível confirmar a alteração com segurança.',
          code: 'failed-precondition',
        ),
        'not-found' => const InvestmentFailure(
          kind: InvestmentFailureKind.notFound,
          safeMessage: 'O item solicitado não foi encontrado.',
          code: 'not-found',
        ),
        'already-exists' => const InvestmentFailure(
          kind: InvestmentFailureKind.alreadyExists,
          safeMessage: 'Este item já existe.',
          code: 'already-exists',
        ),
        _ => const InvestmentFailure(
          kind: InvestmentFailureKind.unknown,
          safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const InvestmentFailure(
      kind: InvestmentFailureKind.unknown,
      safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      code: 'unknown_investment_error',
    );
  }

  static bool _isUncertain(Object error) => mapFailure(error).isUncertain;

  static void _requireMutationId(String mutationId) {
    if (mutationId.isEmpty || mutationId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Não foi possível identificar esta tentativa.',
        code: 'invalid_investment_income_mutation_id',
      );
    }
  }

  static InvestmentFailure _concurrencyFailure() => const InvestmentFailure(
    kind: InvestmentFailureKind.aborted,
    safeMessage:
        'Os dados foram alterados em outro lugar. Atualize e tente novamente.',
    code: 'investment_concurrent_change',
  );

  static List<InvestmentDocumentData> _documents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
            InvestmentDocumentData(id: document.id, data: document.data()),
      )
      .toList(growable: false);

  static int _compareOperations(
    InvestmentOperation first,
    InvestmentOperation second,
  ) {
    final int byDate = first.occurredAt.compareTo(second.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    final int byCreation = first.createdAt.compareTo(second.createdAt);
    return byCreation != 0 ? byCreation : first.id.compareTo(second.id);
  }

  static int _compareIncomeEvents(
    InvestmentIncomeEvent first,
    InvestmentIncomeEvent second,
  ) {
    final int byDate = first.relevantDate.compareTo(second.relevantDate);
    if (byDate != 0) {
      return byDate;
    }
    final int byCreation = first.createdAt.compareTo(second.createdAt);
    return byCreation != 0 ? byCreation : first.id.compareTo(second.id);
  }
}

final class InvestmentDocumentData {
  const InvestmentDocumentData({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
