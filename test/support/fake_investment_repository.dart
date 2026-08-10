import 'dart:async';

import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class FakeInvestmentRepository implements InvestmentRepository {
  final List<InvestmentPortfolio> portfolios = <InvestmentPortfolio>[];
  final List<TrackedInvestmentAsset> assets = <TrackedInvestmentAsset>[];
  final List<InvestmentOperation> operations = <InvestmentOperation>[];

  bool serverConfirmed = true;
  Object? nextFailure;
  Object? nextReadFailure;
  Completer<void>? readBarrier;
  Completer<void>? createPortfolioBarrier;
  int createPortfolioCalls = 0;
  int readCalls = 0;
  final List<String> createPortfolioIds = <String>[];
  final List<String> createOperationIds = <String>[];
  final List<String> voidMutationIds = <String>[];
  int _id = 0;

  @override
  String newPortfolioId({required String ownerId}) => 'portfolio-${++_id}';

  @override
  String newOperationId({required String ownerId}) => 'operation-${++_id}';

  @override
  String newMutationId({required String ownerId}) => 'mutation-${++_id}';

  @override
  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    final Completer<void>? barrier = readBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    final Object? readFailure = nextReadFailure;
    if (readFailure != null) {
      nextReadFailure = null;
      throw readFailure;
    }
    _throwIfNeeded();
    return InvestmentWorkspaceReadResult(
      portfolios: List<InvestmentPortfolio>.unmodifiable(portfolios),
      assets: List<TrackedInvestmentAsset>.unmodifiable(assets),
      operations: List<InvestmentOperation>.unmodifiable(operations),
      isFromServer: serverConfirmed,
      hasPendingWrites: !serverConfirmed,
    );
  }

  @override
  Future<InvestmentPortfolio> createPortfolio({
    required String ownerId,
    required String portfolioId,
    required InvestmentPortfolioDraft draft,
  }) async {
    createPortfolioCalls += 1;
    createPortfolioIds.add(portfolioId);
    final Completer<void>? barrier = createPortfolioBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    _throwIfNeeded();
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentPortfolio value = InvestmentPortfolio(
      id: portfolioId,
      ownerId: ownerId,
      name: draft.normalized().name,
      description: draft.normalized().description,
      isArchived: false,
      archivedAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    );
    portfolios.add(value);
    return value;
  }

  @override
  Future<InvestmentPortfolio> updatePortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required InvestmentPortfolioDraft draft,
  }) async {
    _throwIfNeeded();
    final int index = portfolios.indexWhere((value) => value.id == portfolioId);
    final InvestmentPortfolio current = portfolios[index];
    final InvestmentPortfolio value = InvestmentPortfolio(
      id: current.id,
      ownerId: current.ownerId,
      name: draft.normalized().name,
      description: draft.normalized().description,
      isArchived: current.isArchived,
      archivedAt: current.archivedAt,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 8, 4, 12),
      schemaVersion: 1,
      revision: current.revision + 1,
    );
    portfolios[index] = value;
    return value;
  }

  @override
  Future<InvestmentPortfolio> setPortfolioArchived({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required bool archived,
  }) async {
    _throwIfNeeded();
    final int index = portfolios.indexWhere((value) => value.id == portfolioId);
    final InvestmentPortfolio current = portfolios[index];
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentPortfolio value = InvestmentPortfolio(
      id: current.id,
      ownerId: current.ownerId,
      name: current.name,
      description: current.description,
      isArchived: archived,
      archivedAt: archived ? now : null,
      createdAt: current.createdAt,
      updatedAt: now,
      schemaVersion: 1,
      revision: current.revision + 1,
    );
    portfolios[index] = value;
    return value;
  }

  @override
  Future<TrackedInvestmentAsset> createAsset({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
  }) async {
    _throwIfNeeded();
    final TrackedInvestmentAssetDraft normalized = draft.normalized();
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final TrackedInvestmentAsset value = TrackedInvestmentAsset(
      id: TrackedInvestmentAsset.documentId(
        portfolioId: normalized.portfolioId,
        ticker: normalized.ticker,
      ),
      ownerId: ownerId,
      portfolioId: normalized.portfolioId,
      ticker: normalized.ticker,
      name: normalized.name,
      type: normalized.type,
      currencyCode: 'BRL',
      currentQuantityScaled: 0,
      lastOperationId: null,
      lastOperationAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    );
    assets.add(value);
    return value;
  }

  @override
  Future<InvestmentOperation> createOperation({
    required String ownerId,
    required String operationId,
    required InvestmentOperationDraft draft,
  }) async {
    createOperationIds.add(operationId);
    _throwIfNeeded();
    final InvestmentOperationDraft normalized = draft.normalized(
      now: DateTime.utc(2026, 8, 4, 12),
    );
    final int assetIndex = assets.indexWhere(
      (TrackedInvestmentAsset value) => value.id == normalized.assetId,
    );
    final TrackedInvestmentAsset asset = assets[assetIndex];
    final int quantity = normalized.kind == InvestmentOperationKind.buy
        ? asset.currentQuantityScaled + normalized.quantityScaled
        : asset.currentQuantityScaled - normalized.quantityScaled;
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentOperation value = InvestmentOperation(
      id: operationId,
      ownerId: ownerId,
      portfolioId: normalized.portfolioId,
      assetId: normalized.assetId,
      previousOperationId: asset.lastOperationId,
      previousOperationAt: asset.lastOperationAt,
      kind: normalized.kind,
      occurredAt: normalized.occurredAt,
      quantityScaled: normalized.quantityScaled,
      unitPriceScaled: normalized.unitPriceScaled,
      feesCents: normalized.feesCents,
      notes: normalized.notes,
      isVoided: false,
      voidedAt: null,
      mutationId: operationId,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    );
    operations.add(value);
    assets[assetIndex] = _copyAsset(
      asset,
      quantity: quantity,
      lastOperationId: operationId,
      lastOperationAt: normalized.occurredAt,
    );
    return value;
  }

  @override
  Future<InvestmentOperation> voidOperation({
    required String ownerId,
    required String operationId,
    required int expectedRevision,
    required String mutationId,
  }) async {
    voidMutationIds.add(mutationId);
    _throwIfNeeded();
    final int operationIndex = operations.indexWhere(
      (InvestmentOperation value) => value.id == operationId,
    );
    final InvestmentOperation current = operations[operationIndex];
    final int assetIndex = assets.indexWhere(
      (TrackedInvestmentAsset value) => value.id == current.assetId,
    );
    final TrackedInvestmentAsset asset = assets[assetIndex];
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentOperation value = InvestmentOperation(
      id: current.id,
      ownerId: current.ownerId,
      portfolioId: current.portfolioId,
      assetId: current.assetId,
      previousOperationId: current.previousOperationId,
      previousOperationAt: current.previousOperationAt,
      kind: current.kind,
      occurredAt: current.occurredAt,
      quantityScaled: current.quantityScaled,
      unitPriceScaled: current.unitPriceScaled,
      feesCents: current.feesCents,
      notes: current.notes,
      isVoided: true,
      voidedAt: now,
      mutationId: mutationId,
      createdAt: current.createdAt,
      updatedAt: now,
      schemaVersion: 1,
      revision: current.revision + 1,
    );
    operations[operationIndex] = value;
    final int quantity = current.kind == InvestmentOperationKind.buy
        ? asset.currentQuantityScaled - current.quantityScaled
        : asset.currentQuantityScaled + current.quantityScaled;
    assets[assetIndex] = _copyAsset(
      asset,
      quantity: quantity,
      lastOperationId: current.previousOperationId,
      lastOperationAt: current.previousOperationAt,
    );
    return value;
  }

  void _throwIfNeeded() {
    final Object? failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  TrackedInvestmentAsset _copyAsset(
    TrackedInvestmentAsset asset, {
    required int quantity,
    required String? lastOperationId,
    required DateTime? lastOperationAt,
  }) => TrackedInvestmentAsset(
    id: asset.id,
    ownerId: asset.ownerId,
    portfolioId: asset.portfolioId,
    ticker: asset.ticker,
    name: asset.name,
    type: asset.type,
    currencyCode: asset.currencyCode,
    currentQuantityScaled: quantity,
    lastOperationId: lastOperationId,
    lastOperationAt: lastOperationAt,
    createdAt: asset.createdAt,
    updatedAt: DateTime.utc(2026, 8, 4, 12),
    schemaVersion: 1,
    revision: asset.revision + 1,
  );
}
