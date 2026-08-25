import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

final AsyncNotifierProvider<InvestmentsController, InvestmentsState>
investmentsControllerProvider =
    AsyncNotifierProvider.autoDispose<InvestmentsController, InvestmentsState>(
      InvestmentsController.new,
    );

final class InvestmentsState {
  const InvestmentsState({
    required this.portfolios,
    required this.assets,
    required this.operations,
    this.incomeEvents = const <InvestmentIncomeEvent>[],
    required this.isServerConfirmed,
  });

  final List<InvestmentPortfolio> portfolios;
  final List<TrackedInvestmentAsset> assets;
  final List<InvestmentOperation> operations;
  final List<InvestmentIncomeEvent> incomeEvents;
  final bool isServerConfirmed;

  List<InvestmentPortfolio> get activePortfolios => portfolios
      .where((InvestmentPortfolio value) => !value.isArchived)
      .toList(growable: false);

  List<InvestmentPortfolio> get archivedPortfolios => portfolios
      .where((InvestmentPortfolio value) => value.isArchived)
      .toList(growable: false);

  InvestmentPortfolio? portfolioById(String id) {
    for (final InvestmentPortfolio portfolio in portfolios) {
      if (portfolio.id == id) {
        return portfolio;
      }
    }
    return null;
  }

  TrackedInvestmentAsset? assetById(String id) {
    for (final TrackedInvestmentAsset asset in assets) {
      if (asset.id == id) {
        return asset;
      }
    }
    return null;
  }

  List<TrackedInvestmentAsset> assetsForPortfolio(String portfolioId) => assets
      .where((TrackedInvestmentAsset asset) => asset.portfolioId == portfolioId)
      .toList(growable: false);

  List<InvestmentOperation> operationsForAsset(String assetId) => operations
      .where((InvestmentOperation operation) => operation.assetId == assetId)
      .toList(growable: false);

  List<InvestmentIncomeEvent> incomeEventsForPortfolio(String portfolioId) =>
      incomeEvents
          .where(
            (InvestmentIncomeEvent event) => event.portfolioId == portfolioId,
          )
          .toList(growable: false);

  InvestmentIncomeEvent? incomeEventById(String id) {
    for (final InvestmentIncomeEvent event in incomeEvents) {
      if (event.id == id) {
        return event;
      }
    }
    return null;
  }

  InvestmentProjection projectionForPortfolio(String portfolioId) =>
      InvestmentProjection.rebuild(
        assets: assetsForPortfolio(portfolioId),
        operations: operations.where(
          (InvestmentOperation operation) =>
              operation.portfolioId == portfolioId,
        ),
      );
}

final class InvestmentsController extends AsyncNotifier<InvestmentsState> {
  @override
  Future<InvestmentsState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<InvestmentsState>();
    state = await AsyncValue.guard<InvestmentsState>(_load);
  }

  Future<InvestmentsState> _load() async {
    final String ownerId = requireInvestmentOwner(ref);
    final InvestmentWorkspaceReadResult result = await ref
        .read(investmentRepositoryProvider)
        .readWorkspace(ownerId: ownerId, serverOnly: true, includeIncome: true);
    if (!result.isFromServer || result.hasPendingWrites) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.failedPrecondition,
        safeMessage:
            'Não foi possível confirmar seus investimentos com o servidor.',
        code: 'investment_workspace_server_confirmation_required',
      );
    }
    final InvestmentsState loaded = InvestmentsState(
      portfolios: result.portfolios,
      assets: result.assets,
      operations: result.operations,
      incomeEvents: result.incomeEvents,
      isServerConfirmed: true,
    );
    for (final InvestmentPortfolio portfolio in loaded.portfolios) {
      loaded.projectionForPortfolio(portfolio.id);
    }
    return loaded;
  }
}

String requireInvestmentOwner(Ref ref) {
  final String? ownerId = verifiedFinancialOwner(ref);
  if (ownerId == null) {
    throw const InvestmentFailure(
      kind: InvestmentFailureKind.unauthenticated,
      safeMessage:
          'Confirme seu acesso e seu perfil antes de consultar investimentos.',
      code: 'investment_access_gate_denied',
    );
  }
  return ownerId;
}

String safeInvestmentErrorMessage(Object error) => error is InvestmentFailure
    ? error.safeMessage
    : 'Não foi possível carregar seus investimentos. Tente novamente.';
