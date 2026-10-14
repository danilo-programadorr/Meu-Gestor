import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

final class InvestmentPositionPerformance {
  const InvestmentPositionPerformance({
    required this.position,
    required this.quote,
    required this.estimatedMarketValueCents,
    required this.unrealizedResultCents,
    required this.returnBasisPoints,
  });

  final InvestmentPosition position;
  final InvestmentQuote? quote;
  final int? estimatedMarketValueCents;
  final int? unrealizedResultCents;
  final int? returnBasisPoints;

  bool get isQuoted => estimatedMarketValueCents != null;
}

/// Resultado econômico decomposto; total estimado só existe com cobertura total.
final class InvestmentPortfolioPerformance {
  const InvestmentPortfolioPerformance({
    required this.positions,
    required this.quotedAssetCount,
    required this.totalAssetCount,
    required this.estimatedMarketValueCents,
    required this.unrealizedResultCents,
    required this.realizedResultCents,
    required this.receivedIncomeCents,
    required this.totalEconomicResultCents,
    required this.investedCostCents,
    required this.openPositionReturnBasisPoints,
    required this.dailyVariationCents,
    required this.dailyVariationBasisPoints,
  });

  final List<InvestmentPositionPerformance> positions;
  final int quotedAssetCount;
  final int totalAssetCount;
  final int? estimatedMarketValueCents;
  final int? unrealizedResultCents;
  final int realizedResultCents;
  final int receivedIncomeCents;
  final int? totalEconomicResultCents;
  final int investedCostCents;
  final int? openPositionReturnBasisPoints;
  final int? dailyVariationCents;
  final int? dailyVariationBasisPoints;

  bool get hasFullCoverage => quotedAssetCount == totalAssetCount;
  bool get hasOpenPositions => totalAssetCount > 0;
}

abstract final class InvestmentPerformanceCalculator {
  static InvestmentPortfolioPerformance calculate({
    required Iterable<InvestmentPosition> positions,
    required Iterable<InvestmentQuote> quotes,
    required int receivedIncomeCents,
    required DateTime referenceInstant,
  }) {
    final Map<String, InvestmentQuote> quotesByTicker =
        <String, InvestmentQuote>{
          for (final InvestmentQuote quote in quotes) quote.ticker: quote,
        };
    final List<InvestmentPositionPerformance> calculated =
        <InvestmentPositionPerformance>[];
    BigInt marketValue = BigInt.zero;
    BigInt unrealized = BigInt.zero;
    BigInt realized = BigInt.zero;
    BigInt investedCost = BigInt.zero;
    BigInt currentMarketValueScaled = BigInt.zero;
    BigInt previousMarketValueScaled = BigInt.zero;
    bool hasCompleteDailyVariation = true;
    int quoted = 0;
    int total = 0;
    for (final InvestmentPosition position in positions) {
      realized += BigInt.from(position.realizedResultCents);
      final InvestmentQuote? candidate = quotesByTicker[position.asset.ticker];
      final InvestmentQuote? quote = candidate?.assetType == position.asset.type
          ? candidate
          : null;
      if (position.isClosed) {
        // Ativo cadastrado continua visível nas telas de mercado mesmo sem
        // posição. Cotação não cria patrimônio, custo ou rentabilidade.
        calculated.add(
          InvestmentPositionPerformance(
            position: position,
            quote: quote,
            estimatedMarketValueCents: null,
            unrealizedResultCents: null,
            returnBasisPoints: null,
          ),
        );
        continue;
      }
      total += 1;
      investedCost += BigInt.from(position.totalCostCents);
      if (quote == null ||
          !quote.hasPrice ||
          quote.isStaleAt(referenceInstant)) {
        hasCompleteDailyVariation = false;
        calculated.add(
          InvestmentPositionPerformance(
            position: position,
            quote: quote,
            estimatedMarketValueCents: null,
            unrealizedResultCents: null,
            returnBasisPoints: null,
          ),
        );
        continue;
      }
      final int value = InvestmentArithmetic.grossAmountCents(
        quantityScaled: position.quantityScaled,
        unitPriceScaled: quote.unitPriceScaled,
      );
      final int gain = value - position.totalCostCents;
      final int returnBps = position.totalCostCents <= 0
          ? 0
          : InvestmentArithmetic.checkedInt64(
              InvestmentArithmetic.roundHalfUp(
                BigInt.from(gain) * BigInt.from(10000),
                BigInt.from(position.totalCostCents),
              ),
            );
      quoted += 1;
      marketValue += BigInt.from(value);
      unrealized += BigInt.from(gain);
      final BigInt currentPositionValueScaled =
          BigInt.from(position.quantityScaled) *
          BigInt.from(quote.unitPriceScaled);
      currentMarketValueScaled += currentPositionValueScaled;
      final int variationBasisPoints = quote.variationBasisPoints!;
      final int previousDenominator = 10000 + variationBasisPoints;
      if (previousDenominator <= 0) {
        hasCompleteDailyVariation = false;
      } else {
        previousMarketValueScaled += InvestmentArithmetic.roundHalfUp(
          currentPositionValueScaled * BigInt.from(10000),
          BigInt.from(previousDenominator),
        );
      }
      calculated.add(
        InvestmentPositionPerformance(
          position: position,
          quote: quote,
          estimatedMarketValueCents: value,
          unrealizedResultCents: gain,
          returnBasisPoints: returnBps,
        ),
      );
    }
    final bool complete = quoted == total;
    final int realizedCents = InvestmentArithmetic.checkedInt64(realized);
    final int? valueCents = complete
        ? InvestmentArithmetic.checkedInt64(marketValue)
        : null;
    final int? unrealizedCents = complete
        ? InvestmentArithmetic.checkedInt64(unrealized)
        : null;
    final int investedCostCents = InvestmentArithmetic.checkedInt64(
      investedCost,
    );
    final int? returnBasisPoints = complete && investedCostCents > 0
        ? InvestmentArithmetic.checkedInt64(
            InvestmentArithmetic.roundHalfUp(
              unrealized * BigInt.from(10000),
              investedCost,
            ),
          )
        : null;
    // A variação diária é reconstruída a partir do fechamento anterior de
    // cada snapshot e só é agregada quando todas as posições têm base válida.
    final bool canCalculateDailyVariation =
        complete &&
        total > 0 &&
        hasCompleteDailyVariation &&
        previousMarketValueScaled > BigInt.zero;
    final BigInt dailyVariationScaled =
        currentMarketValueScaled - previousMarketValueScaled;
    final BigInt dailyVariationCents = InvestmentArithmetic.roundHalfUp(
      dailyVariationScaled,
      BigInt.from(InvestmentScale.moneyConversionDivisor),
    );
    return InvestmentPortfolioPerformance(
      positions: List<InvestmentPositionPerformance>.unmodifiable(calculated),
      quotedAssetCount: quoted,
      totalAssetCount: total,
      estimatedMarketValueCents: valueCents,
      unrealizedResultCents: unrealizedCents,
      realizedResultCents: realizedCents,
      receivedIncomeCents: receivedIncomeCents,
      totalEconomicResultCents: complete
          ? InvestmentArithmetic.checkedInt64(
              unrealized + realized + BigInt.from(receivedIncomeCents),
            )
          : null,
      investedCostCents: investedCostCents,
      openPositionReturnBasisPoints: returnBasisPoints,
      dailyVariationCents: canCalculateDailyVariation
          ? InvestmentArithmetic.checkedInt64(dailyVariationCents)
          : null,
      dailyVariationBasisPoints: canCalculateDailyVariation
          ? InvestmentArithmetic.checkedInt64(
              InvestmentArithmetic.roundHalfUp(
                dailyVariationScaled * BigInt.from(10000),
                previousMarketValueScaled,
              ),
            )
          : null,
    );
  }
}
