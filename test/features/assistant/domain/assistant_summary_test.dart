import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 25,
  );

  AssistantReadOnlySnapshot snapshot({
    AssistantCoreSnapshot? core,
    AssistantCommitmentSnapshot? commitments,
    AssistantInvestmentSnapshot? investments,
  }) => AssistantReadOnlySnapshot(
    generatedAt: DateTime.utc(2026, 8, 25, 15),
    today: today,
    core: core,
    commitments: commitments,
    investments: investments,
  );

  test('resumo mensal separa receitas, despesas e resultado', () {
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: AssistantGuidedQuestion.monthlyOverview,
          snapshot: snapshot(
            core: const AssistantCoreSnapshot(
              totalBalanceCents: 125000,
              activeAccountCount: 2,
              monthIncomeCents: 300000,
              monthExpenseCents: 180000,
              monthTransactionCount: 5,
            ),
          ),
        );

    expect(summary.isAvailable, isTrue);
    expect(summary.metrics.map((value) => value.moneyCents), <int?>[
      300000,
      180000,
      120000,
      null,
    ]);
    expect(summary.periodLabel, contains('2026-08'));
    expect(summary.observation, contains('receitas efetivadas superam'));
  });

  test('pendências mantêm atraso derivado na data civil', () {
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: AssistantGuidedQuestion.commitmentStatus,
          snapshot: snapshot(
            commitments: const AssistantCommitmentSnapshot(
              pendingPayablesCount: 3,
              pendingPayablesCents: 18000,
              overduePayablesCount: 1,
              overduePayablesCents: 5000,
              pendingReceivablesCount: 2,
              pendingReceivablesCents: 9000,
              overdueReceivablesCount: 1,
              overdueReceivablesCents: 2000,
            ),
          ),
        );

    expect(summary.periodLabel, contains('25/08/2026'));
    expect(summary.observation, contains('não alteram o saldo real'));
    expect(summary.observation, contains('atraso é calculado'));
  });

  test('investimentos não simulam cotação nem rentabilidade', () {
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: AssistantGuidedQuestion.investmentOverview,
          snapshot: snapshot(
            investments: const AssistantInvestmentSnapshot(
              activePortfolioCount: 1,
              trackedAssetCount: 2,
              openPositionCount: 2,
              totalCostCents: 100000,
              realizedResultCents: 5000,
              receivedIncomeCents: 2500,
            ),
          ),
        );

    expect(summary.observation, contains('histórico manual confirmado'));
    expect(summary.observation, contains('não são estimadas'));
  });

  test('fonte ausente é apresentada sem estimativa', () {
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: AssistantGuidedQuestion.currentBalance,
          snapshot: snapshot(),
        );

    expect(summary.isAvailable, isFalse);
    expect(summary.metrics, isEmpty);
    expect(summary.observation, contains('Nenhum valor foi estimado'));
  });

  test('resultado fora de int64 falha fechado', () {
    expect(
      () => AssistantDeterministicSummaryBuilder.build(
        question: AssistantGuidedQuestion.monthlyOverview,
        snapshot: snapshot(
          core: const AssistantCoreSnapshot(
            totalBalanceCents: 0,
            activeAccountCount: 0,
            monthIncomeCents: 9223372036854775807,
            monthExpenseCents: -1,
            monthTransactionCount: 0,
          ),
        ),
      ),
      throwsA(isA<AssistantFailure>()),
    );
  });
}
