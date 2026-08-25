import 'dart:async';

import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class FakeInvestmentRepository implements InvestmentRepository {
  final List<InvestmentPortfolio> portfolios = <InvestmentPortfolio>[];
  final List<TrackedInvestmentAsset> assets = <TrackedInvestmentAsset>[];
  final List<InvestmentOperation> operations = <InvestmentOperation>[];
  final List<InvestmentIncomeEvent> incomeEvents = <InvestmentIncomeEvent>[];

  bool serverConfirmed = true;
  Object? nextFailure;
  Object? nextIncomeFailureAfterWrite;
  Object? nextReadFailure;
  Completer<void>? readBarrier;
  Completer<void>? createPortfolioBarrier;
  Completer<void>? incomeActionBarrier;
  int createPortfolioCalls = 0;
  int readCalls = 0;
  bool? lastIncludeIncome;
  final List<String> createPortfolioIds = <String>[];
  final List<String> createOperationIds = <String>[];
  final List<String> voidMutationIds = <String>[];
  final List<String> createIncomeIds = <String>[];
  final List<String> incomeMutationIds = <String>[];
  int _id = 0;

  int get generatedIdCount => _id;

  @override
  String newPortfolioId({required String ownerId}) => 'portfolio-${++_id}';

  @override
  String newOperationId({required String ownerId}) => 'operation-${++_id}';

  @override
  String newIncomeEventId({required String ownerId}) => 'income-${++_id}';

  @override
  String newMutationId({required String ownerId}) => 'mutation-${++_id}';

  @override
  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
    bool includeIncome = true,
  }) async {
    readCalls += 1;
    lastIncludeIncome = includeIncome;
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
      incomeEvents: includeIncome
          ? List<InvestmentIncomeEvent>.unmodifiable(incomeEvents)
          : const <InvestmentIncomeEvent>[],
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
      hasHistory: false,
      createdAt: now,
      updatedAt: now,
      schemaVersion: InvestmentPortfolio.currentSchemaVersion,
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
      hasHistory: current.hasHistory,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 8, 4, 12),
      schemaVersion: current.schemaVersion,
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
      hasHistory: current.hasHistory,
      createdAt: current.createdAt,
      updatedAt: now,
      schemaVersion: current.schemaVersion,
      revision: current.revision + 1,
    );
    portfolios[index] = value;
    return value;
  }

  @override
  Future<void> deleteEmptyPortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
  }) async {
    _throwIfNeeded();
    final int index = portfolios.indexWhere(
      (InvestmentPortfolio value) => value.id == portfolioId,
    );
    if (index < 0) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.notFound,
        safeMessage: 'Carteira não encontrada.',
      );
    }
    final InvestmentPortfolio current = portfolios[index];
    if (current.ownerId != ownerId || current.revision != expectedRevision) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.aborted,
        safeMessage: 'A carteira foi alterada. Atualize e tente novamente.',
      );
    }
    final bool hasHistory =
        current.schemaVersion != InvestmentPortfolio.currentSchemaVersion ||
        current.hasHistory ||
        assets.any(
          (TrackedInvestmentAsset value) => value.portfolioId == portfolioId,
        ) ||
        operations.any(
          (InvestmentOperation value) => value.portfolioId == portfolioId,
        ) ||
        incomeEvents.any(
          (InvestmentIncomeEvent value) => value.portfolioId == portfolioId,
        );
    if (hasHistory) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.failedPrecondition,
        safeMessage:
            'Esta carteira possui histórico. Para preservá-lo, arquive a carteira em vez de excluí-la.',
      );
    }
    portfolios.removeAt(index);
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
    final int portfolioIndex = portfolios.indexWhere(
      (InvestmentPortfolio portfolio) => portfolio.id == normalized.portfolioId,
    );
    final InvestmentPortfolio portfolio = portfolios[portfolioIndex];
    if (!portfolio.hasHistory) {
      portfolios[portfolioIndex] = InvestmentPortfolio(
        id: portfolio.id,
        ownerId: portfolio.ownerId,
        name: portfolio.name,
        description: portfolio.description,
        isArchived: portfolio.isArchived,
        archivedAt: portfolio.archivedAt,
        hasHistory: true,
        createdAt: portfolio.createdAt,
        updatedAt: now,
        schemaVersion: portfolio.schemaVersion,
        revision: portfolio.revision + 1,
      );
    }
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

  @override
  Future<InvestmentIncomeEvent> createIncomeEvent({
    required String ownerId,
    required String eventId,
    required InvestmentIncomeDraft draft,
  }) async {
    createIncomeIds.add(eventId);
    await _awaitIncomeBarrier();
    _throwIfNeeded();
    final TrackedInvestmentAsset asset = _incomeAsset(
      draft.portfolioId,
      draft.assetId,
    );
    final InvestmentIncomeDraft normalized = draft.normalized(
      assetType: asset.type,
    );
    final InvestmentIncomeEvent? existing = incomeEvents
        .where((InvestmentIncomeEvent value) => value.id == eventId)
        .firstOrNull;
    if (existing != null) {
      return existing;
    }
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentIncomeEvent value = InvestmentIncomeEvent(
      id: eventId,
      ownerId: ownerId,
      portfolioId: normalized.portfolioId,
      assetId: normalized.assetId,
      type: normalized.type,
      status: InvestmentIncomeStatus.expected,
      inputMode: normalized.inputMode,
      exDate: normalized.exDate,
      expectedPaymentDate: normalized.expectedPaymentDate,
      receivedDate: null,
      eligibleQuantityScaled: normalized.eligibleQuantityScaled,
      unitAmountScaled: normalized.unitAmountScaled,
      grossAmountCents: normalized.grossAmountCents,
      withholdingTaxCents: normalized.withholdingTaxCents,
      netAmountCents: normalized.netAmountCents,
      notes: normalized.notes,
      originType: InvestmentIncomeOriginType.manual,
      externalId: null,
      cancelledAt: null,
      voidedAt: null,
      mutationId: eventId,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    );
    incomeEvents.add(value);
    _throwIncomeFailureAfterWrite();
    return value;
  }

  @override
  Future<InvestmentIncomeEvent> updateExpectedIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeDraft draft,
  }) async {
    incomeMutationIds.add(mutationId);
    await _awaitIncomeBarrier();
    _throwIfNeeded();
    final int index = incomeEvents.indexWhere((value) => value.id == eventId);
    final InvestmentIncomeEvent current = incomeEvents[index];
    if (!current.isExpected || current.revision != expectedRevision) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.aborted,
        safeMessage: 'Conflito.',
      );
    }
    final TrackedInvestmentAsset asset = _incomeAsset(
      current.portfolioId,
      current.assetId,
    );
    final InvestmentIncomeDraft normalized = draft.normalized(
      assetType: asset.type,
    );
    final InvestmentIncomeEvent value = _copyIncome(
      current,
      type: normalized.type,
      inputMode: normalized.inputMode,
      exDate: normalized.exDate,
      expectedPaymentDate: normalized.expectedPaymentDate,
      eligibleQuantityScaled: normalized.eligibleQuantityScaled,
      unitAmountScaled: normalized.unitAmountScaled,
      grossAmountCents: normalized.grossAmountCents,
      withholdingTaxCents: normalized.withholdingTaxCents,
      netAmountCents: normalized.netAmountCents,
      notes: normalized.notes,
      mutationId: mutationId,
    );
    incomeEvents[index] = value;
    _throwIncomeFailureAfterWrite();
    return value;
  }

  @override
  Future<InvestmentIncomeEvent> receiveIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required DateTime receivedDate,
  }) => _transitionIncome(
    eventId: eventId,
    expectedRevision: expectedRevision,
    mutationId: mutationId,
    target: InvestmentIncomeStatus.received,
    receivedDate: InvestmentIncomeEvent.normalizeCivilDate(receivedDate),
  );

  @override
  Future<InvestmentIncomeEvent> cancelIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) => _transitionIncome(
    eventId: eventId,
    expectedRevision: expectedRevision,
    mutationId: mutationId,
    target: InvestmentIncomeStatus.cancelled,
  );

  @override
  Future<InvestmentIncomeEvent> voidIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) => _transitionIncome(
    eventId: eventId,
    expectedRevision: expectedRevision,
    mutationId: mutationId,
    target: InvestmentIncomeStatus.voided,
  );

  Future<InvestmentIncomeEvent> _transitionIncome({
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeStatus target,
    DateTime? receivedDate,
  }) async {
    incomeMutationIds.add(mutationId);
    await _awaitIncomeBarrier();
    _throwIfNeeded();
    final int index = incomeEvents.indexWhere((value) => value.id == eventId);
    final InvestmentIncomeEvent current = incomeEvents[index];
    if (current.status == target && current.mutationId == mutationId) {
      return current;
    }
    if (!current.canTransitionTo(target) ||
        current.revision != expectedRevision) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.aborted,
        safeMessage: 'Conflito.',
      );
    }
    if (target == InvestmentIncomeStatus.received) {
      _incomeAsset(current.portfolioId, current.assetId);
    }
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    final InvestmentIncomeEvent value = _copyIncome(
      current,
      status: target,
      receivedDate: target == InvestmentIncomeStatus.received
          ? receivedDate
          : current.receivedDate,
      cancelledAt: target == InvestmentIncomeStatus.cancelled ? now : null,
      voidedAt: target == InvestmentIncomeStatus.voided ? now : null,
      mutationId: mutationId,
    );
    incomeEvents[index] = value;
    _throwIncomeFailureAfterWrite();
    return value;
  }

  Future<void> _awaitIncomeBarrier() async {
    final Completer<void>? barrier = incomeActionBarrier;
    if (barrier != null) {
      await barrier.future;
    }
  }

  TrackedInvestmentAsset _incomeAsset(String portfolioId, String assetId) {
    final InvestmentPortfolio? portfolio = portfolios
        .where((InvestmentPortfolio value) => value.id == portfolioId)
        .firstOrNull;
    final TrackedInvestmentAsset? asset = assets
        .where((TrackedInvestmentAsset value) => value.id == assetId)
        .firstOrNull;
    if (portfolio == null ||
        portfolio.isArchived ||
        asset == null ||
        asset.portfolioId != portfolio.id) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.failedPrecondition,
        safeMessage: 'A carteira ou o ativo não está disponível.',
      );
    }
    return asset;
  }

  void _throwIfNeeded() {
    final Object? failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  void _throwIncomeFailureAfterWrite() {
    final Object? failure = nextIncomeFailureAfterWrite;
    if (failure != null) {
      nextIncomeFailureAfterWrite = null;
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

  InvestmentIncomeEvent _copyIncome(
    InvestmentIncomeEvent value, {
    InvestmentIncomeType? type,
    InvestmentIncomeStatus? status,
    InvestmentIncomeInputMode? inputMode,
    DateTime? exDate,
    DateTime? expectedPaymentDate,
    DateTime? receivedDate,
    int? eligibleQuantityScaled,
    int? unitAmountScaled,
    int? grossAmountCents,
    int? withholdingTaxCents,
    int? netAmountCents,
    String? notes,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    required String mutationId,
  }) => InvestmentIncomeEvent(
    id: value.id,
    ownerId: value.ownerId,
    portfolioId: value.portfolioId,
    assetId: value.assetId,
    type: type ?? value.type,
    status: status ?? value.status,
    inputMode: inputMode ?? value.inputMode,
    exDate: exDate ?? value.exDate,
    expectedPaymentDate: expectedPaymentDate ?? value.expectedPaymentDate,
    receivedDate: receivedDate ?? value.receivedDate,
    eligibleQuantityScaled:
        eligibleQuantityScaled ?? value.eligibleQuantityScaled,
    unitAmountScaled: unitAmountScaled ?? value.unitAmountScaled,
    grossAmountCents: grossAmountCents ?? value.grossAmountCents,
    withholdingTaxCents: withholdingTaxCents ?? value.withholdingTaxCents,
    netAmountCents: netAmountCents ?? value.netAmountCents,
    notes: notes ?? value.notes,
    originType: value.originType,
    externalId: value.externalId,
    cancelledAt: cancelledAt ?? value.cancelledAt,
    voidedAt: voidedAt ?? value.voidedAt,
    mutationId: mutationId,
    createdAt: value.createdAt,
    updatedAt: DateTime.utc(2026, 8, 4, 12),
    schemaVersion: value.schemaVersion,
    revision: value.revision + 1,
  );
}
