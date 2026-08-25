import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class InvestmentWorkspaceReadResult {
  const InvestmentWorkspaceReadResult({
    required this.portfolios,
    required this.assets,
    required this.operations,
    this.incomeEvents = const <InvestmentIncomeEvent>[],
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<InvestmentPortfolio> portfolios;
  final List<TrackedInvestmentAsset> assets;
  final List<InvestmentOperation> operations;
  final List<InvestmentIncomeEvent> incomeEvents;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class InvestmentRepository {
  String newPortfolioId({required String ownerId});
  String newOperationId({required String ownerId});
  String newIncomeEventId({required String ownerId});
  String newMutationId({required String ownerId});

  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
    bool includeIncome = true,
  });

  Future<InvestmentPortfolio> createPortfolio({
    required String ownerId,
    required String portfolioId,
    required InvestmentPortfolioDraft draft,
  });

  Future<InvestmentPortfolio> updatePortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required InvestmentPortfolioDraft draft,
  });

  Future<InvestmentPortfolio> setPortfolioArchived({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required bool archived,
  });

  /// Exclui permanentemente uma carteira somente quando não existe ativo,
  /// operação ou provento vinculado a ela.
  Future<void> deleteEmptyPortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
  });

  Future<TrackedInvestmentAsset> createAsset({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
  });

  Future<TrackedInvestmentAsset> updateAsset({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
    required TrackedInvestmentAssetUpdate update,
  });

  Future<TrackedInvestmentAsset> setAssetArchived({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
    required bool archived,
  });

  /// Exclui definitivamente apenas um ativo sem operações nem proventos.
  Future<void> deleteEmptyAsset({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
  });

  Future<InvestmentOperation> createOperation({
    required String ownerId,
    required String operationId,
    required InvestmentOperationDraft draft,
  });

  Future<InvestmentOperation> voidOperation({
    required String ownerId,
    required String operationId,
    required int expectedRevision,
    required String mutationId,
  });

  Future<InvestmentIncomeEvent> createIncomeEvent({
    required String ownerId,
    required String eventId,
    required InvestmentIncomeDraft draft,
  });

  Future<InvestmentIncomeEvent> updateExpectedIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeDraft draft,
  });

  Future<InvestmentIncomeEvent> receiveIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required DateTime receivedDate,
  });

  Future<InvestmentIncomeEvent> cancelIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  });

  Future<InvestmentIncomeEvent> voidIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  });
}
