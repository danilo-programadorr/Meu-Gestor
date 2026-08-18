import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_tools.dart';

void main() {
  group('InvestmentTools', () {
    test('calcula juros simples somente com inteiros', () {
      final result = InvestmentTools.simpleInterest(
        principalCents: 100000,
        annualRateBasisPoints: 1200,
        days: 365,
      );
      expect(result.interestCents, 12000);
      expect(result.totalCents, 112000);
    });
    test('calcula juros compostos e aportes por períodos mensais', () {
      final result = InvestmentTools.compoundInterest(
        principalCents: 100000,
        monthlyRateBasisPoints: 100,
        months: 2,
        monthlyContributionCents: 10000,
      );
      expect(result.totalCents, 122110);
    });
    test('primeiro milhão não depende do relógio ou de dados externos', () {
      final result = InvestmentTools.firstMillion(
        initialCents: 0,
        monthlyContributionCents: 10000000,
        monthlyRateBasisPoints: 0,
      );
      expect(result.periods, 10);
      expect(result.amountCents, 100000000);
    });
    test('calcula aumento, desconto, Graham e Bazin deterministicamente', () {
      expect(
        InvestmentTools.percentage(
          baseCents: 10000,
          rateBasisPoints: 1500,
          operation: PercentageOperation.increase,
        ).resultCents,
        11500,
      );
      expect(
        InvestmentTools.percentage(
          baseCents: 10000,
          rateBasisPoints: 1500,
          operation: PercentageOperation.discount,
        ).resultCents,
        8500,
      );
      expect(
        InvestmentTools.grahamFairPriceCents(
          earningsPerShareCents: 100,
          bookValuePerShareCents: 400,
        ),
        948,
      );
      expect(
        InvestmentTools.bazinCeilingPriceCents(
          annualDividendPerShareCents: 60,
          desiredYieldBasisPoints: 600,
        ),
        1000,
      );
    });
    test('rejeita entradas incompatíveis', () {
      expect(
        () => InvestmentTools.simpleInterest(
          principalCents: -1,
          annualRateBasisPoints: 1,
          days: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => InvestmentTools.bazinCeilingPriceCents(
          annualDividendPerShareCents: 1,
          desiredYieldBasisPoints: 0,
        ),
        throwsArgumentError,
      );
    });
    test(
      'análise manual declara dados insuficientes e não recomenda operações',
      () {
        final analysis = ManualAssetAnalysis(
          kind: ManualAssetKind.stock,
          positive: false,
          attention: false,
          completedChecklistItems: 0,
          totalChecklistItems: 5,
        );
        expect(
          analysis.findings.single.kind,
          InvestmentFindingKind.insufficient,
        );
      },
    );
    test('comparação manual não cria ranking ou recomendação', () {
      final comparison = ManualAssetComparison(
        firstName: 'Ativo A',
        firstChecklistItems: 4,
        secondName: 'Ativo B',
        secondChecklistItems: 2,
      );
      expect(comparison.finding.kind, InvestmentFindingKind.attention);
      expect(comparison.finding.message, contains('não é recomendação'));
    });
  });
}
