import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

typedef InvestmentPremiumAccessReader =
    InvestmentPremiumAccessState? Function();

final class PremiumGuardedInvestmentRepository implements InvestmentRepository {
  const PremiumGuardedInvestmentRepository({
    required InvestmentRepository delegate,
    required InvestmentPremiumAccessReader accessReader,
  }) : _delegate = delegate,
       _accessReader = accessReader;

  final InvestmentRepository _delegate;
  final InvestmentPremiumAccessReader _accessReader;

  @override
  String newPortfolioId({required String ownerId}) =>
      _delegate.newPortfolioId(ownerId: ownerId);

  @override
  String newOperationId({required String ownerId}) =>
      _delegate.newOperationId(ownerId: ownerId);

  @override
  String newIncomeEventId({required String ownerId}) =>
      _delegate.newIncomeEventId(ownerId: ownerId);

  @override
  String newMutationId({required String ownerId}) =>
      _delegate.newMutationId(ownerId: ownerId);

  @override
  Future<InvestmentWorkspaceReadResult> readWorkspace({
    required String ownerId,
    required bool serverOnly,
    bool includeIncome = true,
  }) {
    _requireRead(PremiumCapability.investmentsManual);
    if (includeIncome) {
      _requireRead(PremiumCapability.investmentIncome);
    }
    return _delegate.readWorkspace(
      ownerId: ownerId,
      serverOnly: serverOnly,
      includeIncome: includeIncome,
    );
  }

  @override
  Future<InvestmentPortfolio> createPortfolio({
    required String ownerId,
    required String portfolioId,
    required InvestmentPortfolioDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.createPortfolio(
      ownerId: ownerId,
      portfolioId: portfolioId,
      draft: draft,
    );
  }

  @override
  Future<InvestmentPortfolio> updatePortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required InvestmentPortfolioDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.updatePortfolio(
      ownerId: ownerId,
      portfolioId: portfolioId,
      expectedRevision: expectedRevision,
      draft: draft,
    );
  }

  @override
  Future<InvestmentPortfolio> setPortfolioArchived({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
    required bool archived,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.setPortfolioArchived(
      ownerId: ownerId,
      portfolioId: portfolioId,
      expectedRevision: expectedRevision,
      archived: archived,
    );
  }

  @override
  Future<void> deleteEmptyPortfolio({
    required String ownerId,
    required String portfolioId,
    required int expectedRevision,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.deleteEmptyPortfolio(
      ownerId: ownerId,
      portfolioId: portfolioId,
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<TrackedInvestmentAsset> createAsset({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.createAsset(ownerId: ownerId, draft: draft);
  }

  @override
  Future<TrackedInvestmentAsset> updateAsset({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
    required TrackedInvestmentAssetUpdate update,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.updateAsset(
      ownerId: ownerId,
      assetId: assetId,
      expectedRevision: expectedRevision,
      update: update,
    );
  }

  @override
  Future<TrackedInvestmentAsset> setAssetArchived({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
    required bool archived,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.setAssetArchived(
      ownerId: ownerId,
      assetId: assetId,
      expectedRevision: expectedRevision,
      archived: archived,
    );
  }

  @override
  Future<void> deleteEmptyAsset({
    required String ownerId,
    required String assetId,
    required int expectedRevision,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.deleteEmptyAsset(
      ownerId: ownerId,
      assetId: assetId,
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<InvestmentOperation> createOperation({
    required String ownerId,
    required String operationId,
    required InvestmentOperationDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.createOperation(
      ownerId: ownerId,
      operationId: operationId,
      draft: draft,
    );
  }

  @override
  Future<InvestmentOperation> voidOperation({
    required String ownerId,
    required String operationId,
    required int expectedRevision,
    required String mutationId,
  }) {
    _requireMutation(PremiumCapability.investmentsManual);
    return _delegate.voidOperation(
      ownerId: ownerId,
      operationId: operationId,
      expectedRevision: expectedRevision,
      mutationId: mutationId,
    );
  }

  @override
  Future<InvestmentIncomeEvent> createIncomeEvent({
    required String ownerId,
    required String eventId,
    required InvestmentIncomeDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentIncome);
    return _delegate.createIncomeEvent(
      ownerId: ownerId,
      eventId: eventId,
      draft: draft,
    );
  }

  @override
  Future<InvestmentIncomeEvent> updateExpectedIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required InvestmentIncomeDraft draft,
  }) {
    _requireMutation(PremiumCapability.investmentIncome);
    return _delegate.updateExpectedIncomeEvent(
      ownerId: ownerId,
      eventId: eventId,
      expectedRevision: expectedRevision,
      mutationId: mutationId,
      draft: draft,
    );
  }

  @override
  Future<InvestmentIncomeEvent> receiveIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
    required DateTime receivedDate,
  }) {
    _requireMutation(PremiumCapability.investmentIncome);
    return _delegate.receiveIncomeEvent(
      ownerId: ownerId,
      eventId: eventId,
      expectedRevision: expectedRevision,
      mutationId: mutationId,
      receivedDate: receivedDate,
    );
  }

  @override
  Future<InvestmentIncomeEvent> cancelIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) {
    _requireMutation(PremiumCapability.investmentIncome);
    return _delegate.cancelIncomeEvent(
      ownerId: ownerId,
      eventId: eventId,
      expectedRevision: expectedRevision,
      mutationId: mutationId,
    );
  }

  @override
  Future<InvestmentIncomeEvent> voidIncomeEvent({
    required String ownerId,
    required String eventId,
    required int expectedRevision,
    required String mutationId,
  }) {
    _requireMutation(PremiumCapability.investmentIncome);
    return _delegate.voidIncomeEvent(
      ownerId: ownerId,
      eventId: eventId,
      expectedRevision: expectedRevision,
      mutationId: mutationId,
    );
  }

  void _requireRead(PremiumCapability capability) {
    final InvestmentPremiumAccessState? access = _accessReader();
    if (access?.canRead(capability) != true) {
      throw _failure(access);
    }
  }

  void _requireMutation(PremiumCapability capability) {
    final InvestmentPremiumAccessState? access = _accessReader();
    if (access?.canMutate(capability) != true) {
      throw _failure(access);
    }
  }

  static InvestmentFailure _failure(InvestmentPremiumAccessState? access) {
    final bool confirmationUnavailable =
        access == null ||
        access.status == InvestmentPremiumAccessStatus.confirmationError;
    return InvestmentFailure(
      kind: confirmationUnavailable
          ? InvestmentFailureKind.premiumConfirmationUnavailable
          : InvestmentFailureKind.premiumRequired,
      safeMessage: confirmationUnavailable
          ? 'Não foi possível confirmar o Premium. Tente novamente.'
          : 'Esta ação requer acesso Premium integral.',
      code: confirmationUnavailable
          ? 'investment_premium_confirmation_required'
          : 'investment_premium_mutation_denied',
    );
  }
}
