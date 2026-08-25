import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

final assistantReadModelProvider = Provider.autoDispose<AssistantReadModel>((
  Ref ref,
) {
  final DateTime now = ref.watch(financialClockProvider)().toUtc();
  return buildAssistantReadModel(
    now: now,
    workspace: ref.watch(financialWorkspaceProvider),
    payables: ref.watch(payablesControllerProvider),
    receivables: ref.watch(receivablesControllerProvider),
    investments: ref.watch(investmentsControllerProvider),
  );
});

final class AssistantReadModel {
  const AssistantReadModel({
    required this.snapshot,
    required this.isLoading,
    required this.unavailableSources,
  });

  final AssistantReadOnlySnapshot snapshot;
  final bool isLoading;
  final Set<AssistantContextSource> unavailableSources;
}

AssistantReadModel buildAssistantReadModel({
  required DateTime now,
  required AsyncValue<FinancialWorkspace> workspace,
  required AsyncValue<FinancialCommitmentsState<Payable>> payables,
  required AsyncValue<FinancialCommitmentsState<Receivable>> receivables,
  required AsyncValue<InvestmentsState> investments,
}) {
  final DateTime generatedAt = now.toUtc();
  final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(generatedAt);
  final Set<AssistantContextSource> unavailable = <AssistantContextSource>{};

  final FinancialWorkspace? workspaceValue = workspace.value;
  final FinancialWorkspace? confirmedWorkspace =
      workspaceValue != null &&
          workspaceValue.accounts.isServerConfirmed &&
          workspaceValue.categories.isServerConfirmed &&
          workspaceValue.transactions.isServerConfirmed
      ? workspaceValue
      : null;
  if (confirmedWorkspace == null) {
    unavailable.addAll(const <AssistantContextSource>{
      AssistantContextSource.accounts,
      AssistantContextSource.categories,
      AssistantContextSource.transactions,
      AssistantContextSource.dashboardSummary,
    });
  }

  final FinancialCommitmentsState<Payable>? payablesValue = payables.value;
  final FinancialCommitmentsState<Payable>? confirmedPayables =
      payablesValue?.isServerConfirmed == true ? payablesValue : null;
  if (confirmedPayables == null) {
    unavailable.add(AssistantContextSource.payables);
  }
  final FinancialCommitmentsState<Receivable>? receivablesValue =
      receivables.value;
  final FinancialCommitmentsState<Receivable>? confirmedReceivables =
      receivablesValue?.isServerConfirmed == true ? receivablesValue : null;
  if (confirmedReceivables == null) {
    unavailable.add(AssistantContextSource.receivables);
  }

  final InvestmentsState? investmentsValue = investments.value;
  final InvestmentsState? confirmedInvestments =
      investmentsValue?.isServerConfirmed == true ? investmentsValue : null;
  if (confirmedInvestments == null) {
    unavailable.addAll(const <AssistantContextSource>{
      AssistantContextSource.investmentPortfolios,
      AssistantContextSource.investmentAssets,
      AssistantContextSource.investmentOperations,
      AssistantContextSource.investmentIncome,
      AssistantContextSource.investmentPerformance,
    });
  }

  AssistantCoreSnapshot? core;
  AssistantCommitmentSnapshot? commitments;
  AssistantInvestmentSnapshot? investmentSnapshot;
  try {
    if (confirmedWorkspace != null) {
      core = _buildCore(confirmedWorkspace, generatedAt);
    }
  } on Object {
    unavailable.addAll(const <AssistantContextSource>{
      AssistantContextSource.accounts,
      AssistantContextSource.categories,
      AssistantContextSource.transactions,
      AssistantContextSource.dashboardSummary,
    });
  }
  try {
    if (confirmedPayables != null && confirmedReceivables != null) {
      commitments = _buildCommitments(
        payables: confirmedPayables.commitments,
        receivables: confirmedReceivables.commitments,
        today: today,
      );
    }
  } on Object {
    unavailable.addAll(const <AssistantContextSource>{
      AssistantContextSource.payables,
      AssistantContextSource.receivables,
    });
  }
  try {
    if (confirmedInvestments != null) {
      investmentSnapshot = _buildInvestments(confirmedInvestments);
    }
  } on Object {
    unavailable.addAll(const <AssistantContextSource>{
      AssistantContextSource.investmentPortfolios,
      AssistantContextSource.investmentAssets,
      AssistantContextSource.investmentOperations,
      AssistantContextSource.investmentIncome,
      AssistantContextSource.investmentPerformance,
    });
  }

  return AssistantReadModel(
    snapshot: AssistantReadOnlySnapshot(
      generatedAt: generatedAt,
      today: today,
      core: core,
      commitments: commitments,
      investments: investmentSnapshot,
    ),
    isLoading:
        workspace.isLoading ||
        payables.isLoading ||
        receivables.isLoading ||
        investments.isLoading,
    unavailableSources: Set<AssistantContextSource>.unmodifiable(unavailable),
  );
}

AssistantCoreSnapshot _buildCore(FinancialWorkspace workspace, DateTime now) =>
    AssistantCoreSnapshot(
      totalBalanceCents: workspace.summary.totalCurrentBalance.cents,
      activeAccountCount: workspace.accounts.accounts
          .where((account) => !account.isArchived && account.includeInTotal)
          .length,
      monthIncomeCents: workspace.summary.currentMonth.income.cents,
      monthExpenseCents: workspace.summary.currentMonth.expense.cents,
      monthTransactionCount: workspace.transactions.transactions
          .where(
            (transaction) =>
                !transaction.isVoided &&
                FinancialTransactionDate.isInMonth(transaction.occurredAt, now),
          )
          .length,
    );

AssistantCommitmentSnapshot _buildCommitments({
  required Iterable<Payable> payables,
  required Iterable<Receivable> receivables,
  required SaoPauloCivilDate today,
}) {
  final List<Payable> pendingPayables = payables
      .where((value) => value.isPending)
      .toList(growable: false);
  final List<Receivable> pendingReceivables = receivables
      .where((value) => value.isPending)
      .toList(growable: false);
  final List<Payable> overduePayables = pendingPayables
      .where((value) => value.isOverdue(today))
      .toList(growable: false);
  final List<Receivable> overdueReceivables = pendingReceivables
      .where((value) => value.isOverdue(today))
      .toList(growable: false);
  return AssistantCommitmentSnapshot(
    pendingPayablesCount: pendingPayables.length,
    pendingPayablesCents: _sumCents(
      pendingPayables.map((value) => value.amountCents),
    ),
    overduePayablesCount: overduePayables.length,
    overduePayablesCents: _sumCents(
      overduePayables.map((value) => value.amountCents),
    ),
    pendingReceivablesCount: pendingReceivables.length,
    pendingReceivablesCents: _sumCents(
      pendingReceivables.map((value) => value.amountCents),
    ),
    overdueReceivablesCount: overdueReceivables.length,
    overdueReceivablesCents: _sumCents(
      overdueReceivables.map((value) => value.amountCents),
    ),
  );
}

AssistantInvestmentSnapshot _buildInvestments(InvestmentsState state) {
  final Set<String> activePortfolioIds = state.activePortfolios
      .map((portfolio) => portfolio.id)
      .toSet();
  final List<InvestmentProjection> projections = state.activePortfolios
      .map((portfolio) => state.projectionForPortfolio(portfolio.id))
      .toList(growable: false);
  return AssistantInvestmentSnapshot(
    activePortfolioCount: state.activePortfolios.length,
    trackedAssetCount: state.assets
        .where(
          (asset) =>
              activePortfolioIds.contains(asset.portfolioId) &&
              !asset.isArchived,
        )
        .length,
    openPositionCount: projections
        .expand((projection) => projection.positions)
        .where((position) => !position.isClosed)
        .length,
    totalCostCents: _sumCents(
      projections.map((projection) => projection.totalCostCents),
    ),
    realizedResultCents: _sumCents(
      projections.map((projection) => projection.totalRealizedResultCents),
    ),
    receivedIncomeCents: _sumCents(
      state.incomeEvents
          .where(
            (event) =>
                activePortfolioIds.contains(event.portfolioId) &&
                event.status == InvestmentIncomeStatus.received,
          )
          .map((event) => event.netAmountCents),
    ),
  );
}

int _sumCents(Iterable<int> values) {
  BigInt total = BigInt.zero;
  for (final int value in values) {
    total += BigInt.from(value);
  }
  if (total < _minimumInt64 || total > _maximumInt64) {
    throw const AssistantFailure(AssistantFailureKind.invalidContext);
  }
  return total.toInt();
}

final BigInt _minimumInt64 = BigInt.parse('-9223372036854775808');
final BigInt _maximumInt64 = BigInt.parse('9223372036854775807');
