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
  });

  final List<InvestmentPositionPerformance> positions;
  final int quotedAssetCount;
  final int totalAssetCount;
  final int? estimatedMarketValueCents;
  final int? unrealizedResultCents;
  final int realizedResultCents;
  final int receivedIncomeCents;
  final int? totalEconomicResultCents;

  bool get hasFullCoverage => quotedAssetCount == totalAssetCount;
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
    int quoted = 0;
    int total = 0;
    for (final InvestmentPosition position in positions) {
      realized += BigInt.from(position.realizedResultCents);
      if (position.isClosed) continue;
      total += 1;
      final InvestmentQuote? quote = quotesByTicker[position.asset.ticker];
      if (quote == null ||
          !quote.hasPrice ||
          quote.isStaleAt(referenceInstant) ||
          quote.assetType != position.asset.type) {
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
    );
  }
}
