import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';

enum AssistantGuidedQuestion {
  monthlyOverview,
  currentBalance,
  commitmentStatus,
  investmentOverview,
}

final class AssistantCoreSnapshot {
  const AssistantCoreSnapshot({
    required this.totalBalanceCents,
    required this.activeAccountCount,
    required this.monthIncomeCents,
    required this.monthExpenseCents,
    required this.monthTransactionCount,
  });

  final int totalBalanceCents;
  final int activeAccountCount;
  final int monthIncomeCents;
  final int monthExpenseCents;
  final int monthTransactionCount;
}

final class AssistantCommitmentSnapshot {
  const AssistantCommitmentSnapshot({
    required this.pendingPayablesCount,
    required this.pendingPayablesCents,
    required this.overduePayablesCount,
    required this.overduePayablesCents,
    required this.pendingReceivablesCount,
    required this.pendingReceivablesCents,
    required this.overdueReceivablesCount,
    required this.overdueReceivablesCents,
  });

  final int pendingPayablesCount;
  final int pendingPayablesCents;
  final int overduePayablesCount;
  final int overduePayablesCents;
  final int pendingReceivablesCount;
  final int pendingReceivablesCents;
  final int overdueReceivablesCount;
  final int overdueReceivablesCents;
}

final class AssistantInvestmentSnapshot {
  const AssistantInvestmentSnapshot({
    required this.activePortfolioCount,
    required this.trackedAssetCount,
    required this.openPositionCount,
    required this.totalCostCents,
    required this.realizedResultCents,
    required this.receivedIncomeCents,
  });

  final int activePortfolioCount;
  final int trackedAssetCount;
  final int openPositionCount;
  final int totalCostCents;
  final int realizedResultCents;
  final int receivedIncomeCents;
}

final class AssistantReadOnlySnapshot {
  AssistantReadOnlySnapshot({
    required this.generatedAt,
    required this.today,
    required this.core,
    required this.commitments,
    required this.investments,
  }) {
    if (!generatedAt.isUtc) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  final DateTime generatedAt;
  final SaoPauloCivilDate today;
  final AssistantCoreSnapshot? core;
  final AssistantCommitmentSnapshot? commitments;
  final AssistantInvestmentSnapshot? investments;
}

final class AssistantSummaryMetric {
  const AssistantSummaryMetric.money(this.label, this.moneyCents)
    : count = null;

  const AssistantSummaryMetric.count(this.label, this.count)
    : moneyCents = null;

  final String label;
  final int? moneyCents;
  final int? count;
}

final class AssistantDeterministicSummary {
  const AssistantDeterministicSummary({
    required this.title,
    required this.observation,
    required this.periodLabel,
    required this.metrics,
    required this.sources,
    required this.isAvailable,
  });

  final String title;
  final String observation;
  final String periodLabel;
  final List<AssistantSummaryMetric> metrics;
  final Set<AssistantContextSource> sources;
  final bool isAvailable;
}

abstract final class AssistantDeterministicSummaryBuilder {
  static AssistantDeterministicSummary build({
    required AssistantGuidedQuestion question,
    required AssistantReadOnlySnapshot snapshot,
  }) => switch (question) {
    AssistantGuidedQuestion.monthlyOverview => _monthly(snapshot),
    AssistantGuidedQuestion.currentBalance => _balance(snapshot),
    AssistantGuidedQuestion.commitmentStatus => _commitments(snapshot),
    AssistantGuidedQuestion.investmentOverview => _investments(snapshot),
  };

  static AssistantDeterministicSummary _monthly(
    AssistantReadOnlySnapshot snapshot,
  ) {
    final AssistantCoreSnapshot? core = snapshot.core;
    if (core == null) {
      return _unavailable(
        title: 'Resumo do mês',
        periodLabel: _monthLabel(snapshot.today),
        sources: const <AssistantContextSource>{
          AssistantContextSource.transactions,
          AssistantContextSource.dashboardSummary,
        },
      );
    }
    final int result = _checkedSubtract(
      core.monthIncomeCents,
      core.monthExpenseCents,
    );
    final String observation = result > 0
        ? 'As receitas efetivadas superam as despesas efetivadas no período.'
        : result < 0
        ? 'As despesas efetivadas superam as receitas efetivadas no período.'
        : 'Receitas e despesas efetivadas têm o mesmo total no período.';
    return AssistantDeterministicSummary(
      title: 'Resumo do mês',
      observation: observation,
      periodLabel: _monthLabel(snapshot.today),
      metrics: <AssistantSummaryMetric>[
        AssistantSummaryMetric.money('Receitas', core.monthIncomeCents),
        AssistantSummaryMetric.money('Despesas', core.monthExpenseCents),
        AssistantSummaryMetric.money('Resultado', result),
        AssistantSummaryMetric.count(
          'Lançamentos considerados',
          core.monthTransactionCount,
        ),
      ],
      sources: const <AssistantContextSource>{
        AssistantContextSource.transactions,
        AssistantContextSource.dashboardSummary,
      },
      isAvailable: true,
    );
  }

  static AssistantDeterministicSummary _balance(
    AssistantReadOnlySnapshot snapshot,
  ) {
    final AssistantCoreSnapshot? core = snapshot.core;
    if (core == null) {
      return _unavailable(
        title: 'Saldo atual',
        periodLabel: _positionLabel(snapshot.today),
        sources: const <AssistantContextSource>{
          AssistantContextSource.accounts,
          AssistantContextSource.transactions,
        },
      );
    }
    return AssistantDeterministicSummary(
      title: 'Saldo atual',
      observation:
          'O saldo é derivado das contas incluídas no total e dos lançamentos efetivados não anulados.',
      periodLabel: _positionLabel(snapshot.today),
      metrics: <AssistantSummaryMetric>[
        AssistantSummaryMetric.money('Saldo total', core.totalBalanceCents),
        AssistantSummaryMetric.count(
          'Contas ativas incluídas',
          core.activeAccountCount,
        ),
      ],
      sources: const <AssistantContextSource>{
        AssistantContextSource.accounts,
        AssistantContextSource.transactions,
        AssistantContextSource.dashboardSummary,
      },
      isAvailable: true,
    );
  }

  static AssistantDeterministicSummary _commitments(
    AssistantReadOnlySnapshot snapshot,
  ) {
    final AssistantCommitmentSnapshot? value = snapshot.commitments;
    if (value == null) {
      return _unavailable(
        title: 'Compromissos financeiros',
        periodLabel: _positionLabel(snapshot.today),
        sources: const <AssistantContextSource>{
          AssistantContextSource.payables,
          AssistantContextSource.receivables,
        },
      );
    }
    return AssistantDeterministicSummary(
      title: 'Compromissos financeiros',
      observation:
          'Pendências não alteram o saldo real. O atraso é calculado pela data civil exibida.',
      periodLabel: _positionLabel(snapshot.today),
      metrics: <AssistantSummaryMetric>[
        AssistantSummaryMetric.money(
          'A pagar pendente',
          value.pendingPayablesCents,
        ),
        AssistantSummaryMetric.money(
          'A pagar atrasado',
          value.overduePayablesCents,
        ),
        AssistantSummaryMetric.count(
          'Contas a pagar atrasadas',
          value.overduePayablesCount,
        ),
        AssistantSummaryMetric.money(
          'A receber pendente',
          value.pendingReceivablesCents,
        ),
        AssistantSummaryMetric.money(
          'A receber atrasado',
          value.overdueReceivablesCents,
        ),
        AssistantSummaryMetric.count(
          'Contas a receber atrasadas',
          value.overdueReceivablesCount,
        ),
      ],
      sources: const <AssistantContextSource>{
        AssistantContextSource.payables,
        AssistantContextSource.receivables,
      },
      isAvailable: true,
    );
  }

  static AssistantDeterministicSummary _investments(
    AssistantReadOnlySnapshot snapshot,
  ) {
    final AssistantInvestmentSnapshot? value = snapshot.investments;
    if (value == null) {
      return _unavailable(
        title: 'Investimentos cadastrados',
        periodLabel: _positionLabel(snapshot.today),
        sources: const <AssistantContextSource>{
          AssistantContextSource.investmentPortfolios,
          AssistantContextSource.investmentAssets,
          AssistantContextSource.investmentOperations,
          AssistantContextSource.investmentIncome,
        },
      );
    }
    return AssistantDeterministicSummary(
      title: 'Investimentos cadastrados',
      observation:
          'Os valores refletem apenas o histórico manual confirmado. Cotação e rentabilidade de mercado não são estimadas neste resumo.',
      periodLabel: _positionLabel(snapshot.today),
      metrics: <AssistantSummaryMetric>[
        AssistantSummaryMetric.count(
          'Carteiras ativas',
          value.activePortfolioCount,
        ),
        AssistantSummaryMetric.count(
          'Ativos acompanhados',
          value.trackedAssetCount,
        ),
        AssistantSummaryMetric.count(
          'Posições abertas',
          value.openPositionCount,
        ),
        AssistantSummaryMetric.money('Custo atual', value.totalCostCents),
        AssistantSummaryMetric.money(
          'Resultado realizado',
          value.realizedResultCents,
        ),
        AssistantSummaryMetric.money(
          'Proventos recebidos',
          value.receivedIncomeCents,
        ),
      ],
      sources: const <AssistantContextSource>{
        AssistantContextSource.investmentPortfolios,
        AssistantContextSource.investmentAssets,
        AssistantContextSource.investmentOperations,
        AssistantContextSource.investmentIncome,
        AssistantContextSource.investmentPerformance,
      },
      isAvailable: true,
    );
  }

  static AssistantDeterministicSummary _unavailable({
    required String title,
    required String periodLabel,
    required Set<AssistantContextSource> sources,
  }) => AssistantDeterministicSummary(
    title: title,
    observation:
        'A leitura confirmada necessária está indisponível. Nenhum valor foi estimado.',
    periodLabel: periodLabel,
    metrics: const <AssistantSummaryMetric>[],
    sources: sources,
    isAvailable: false,
  );

  static int _checkedSubtract(int left, int right) {
    final BigInt result = BigInt.from(left) - BigInt.from(right);
    if (result < _minimumInt64 || result > _maximumInt64) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
    return result.toInt();
  }

  static String _monthLabel(SaoPauloCivilDate date) =>
      'Mês civil ${date.year}-${date.month.toString().padLeft(2, '0')} • America/Sao_Paulo';

  static String _positionLabel(SaoPauloCivilDate date) =>
      'Posição em ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • America/Sao_Paulo';

  static final BigInt _minimumInt64 = BigInt.parse('-9223372036854775808');
  static final BigInt _maximumInt64 = BigInt.parse('9223372036854775807');
}
