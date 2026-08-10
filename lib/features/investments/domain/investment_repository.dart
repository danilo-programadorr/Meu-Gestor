import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final class InvestmentWorkspaceReadResult {
  const InvestmentWorkspaceReadResult({
    required this.portfolios,
    required this.assets,
    required this.operations,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<InvestmentPortfolio> portfolios;
  final List<TrackedInvestmentAsset> assets;
  final List<InvestmentOperation> operations;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class InvestmentRepository {
  String newPortfolioId({required String ownerId});
  String newOperationId({required String ownerId});
  String newMutationId({required String ownerId});

  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
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

  Future<TrackedInvestmentAsset> createAsset({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
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
}
