import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_performance.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  final DateTime observed = DateTime.utc(2026, 8, 18, 12);
  final DateTime captured = DateTime.utc(2026, 8, 18, 12, 5);

  InvestmentPosition position({
    String ticker = 'PETR4',
    TrackedInvestmentAssetType type = TrackedInvestmentAssetType.stock,
    int quantity = 100000000,
    int cost = 3000,
    int realized = 25,
  }) => InvestmentPosition(
    asset: TrackedInvestmentAsset(
      id: 'wallet__$ticker',
      ownerId: 'synthetic-owner',
      portfolioId: 'wallet',
      ticker: ticker,
      name: 'Ativo sintético',
      type: type,
      currencyCode: 'BRL',
      currentQuantityScaled: quantity,
      lastOperationId: null,
      lastOperationAt: null,
      createdAt: observed,
      updatedAt: observed,
      schemaVersion: 1,
      revision: 1,
    ),
    quantityScaled: quantity,
    totalCostCents: cost,
    averageUnitPriceScaled: 30000000,
    realizedResultCents: realized,
    activeOperationCount: 1,
  );

  InvestmentQuote quote({
    String ticker = 'PETR4',
    TrackedInvestmentAssetType type = TrackedInvestmentAssetType.stock,
    int price = 35000000,
    InvestmentQuoteAvailability availability =
        InvestmentQuoteAvailability.delayed,
  }) => InvestmentQuote(
    ticker: ticker,
    assetType: type,
    currencyCode: 'BRL',
    unitPriceScaled: price,
    variationBasisPoints: 123,
    observedAt: observed,
    capturedAt: captured,
    declaredDelay: const Duration(minutes: 5),
    staleAfter: captured.add(const Duration(minutes: 20)),
    availability: availability,
    source: 'fixture',
  );

  group('InvestmentQuote', () {
    test('recusa preço zero ou indisponível com preço', () {
      expect(() => quote(price: 0), throwsA(isA<InvestmentFailure>()));
      expect(
        () => quote(availability: InvestmentQuoteAvailability.unavailable),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('não aceita observação posterior à captura', () {
      expect(
        () => InvestmentQuote(
          ticker: 'PETR4',
          assetType: TrackedInvestmentAssetType.stock,
          currencyCode: 'BRL',
          unitPriceScaled: 1,
          variationBasisPoints: 1,
          observedAt: captured.add(const Duration(seconds: 1)),
          capturedAt: captured,
          declaredDelay: Duration.zero,
          staleAfter: captured.add(const Duration(minutes: 1)),
          availability: InvestmentQuoteAvailability.available,
          source: 'fixture',
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('recusa moeda diferente de BRL', () {
      expect(
        () => InvestmentQuote(
          ticker: 'PETR4',
          assetType: TrackedInvestmentAssetType.stock,
          currencyCode: 'USD',
          unitPriceScaled: 1,
          variationBasisPoints: 1,
          observedAt: observed,
          capturedAt: captured,
          declaredDelay: Duration.zero,
          staleAfter: captured.add(const Duration(minutes: 1)),
          availability: InvestmentQuoteAvailability.available,
          source: 'fixture',
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });
  });

  group('InvestmentPerformanceCalculator', () {
    test('separa valor estimado, não realizado, realizado e proventos', () {
      final result = InvestmentPerformanceCalculator.calculate(
        positions: <InvestmentPosition>[position()],
        quotes: <InvestmentQuote>[quote()],
        receivedIncomeCents: 40,
        referenceInstant: captured,
      );

      expect(result.estimatedMarketValueCents, 3500);
      expect(result.unrealizedResultCents, 500);
      expect(result.realizedResultCents, 25);
      expect(result.receivedIncomeCents, 40);
      expect(result.totalEconomicResultCents, 565);
      expect(result.positions.single.returnBasisPoints, 1667);
    });

    test('não apresenta total estimado com cobertura parcial', () {
      final result = InvestmentPerformanceCalculator.calculate(
        positions: <InvestmentPosition>[
          position(),
          position(ticker: 'HGLG11', type: TrackedInvestmentAssetType.fii),
        ],
        quotes: <InvestmentQuote>[quote()],
        receivedIncomeCents: 0,
        referenceInstant: captured,
      );

      expect(result.quotedAssetCount, 1);
      expect(result.totalAssetCount, 2);
      expect(result.estimatedMarketValueCents, isNull);
      expect(result.unrealizedResultCents, isNull);
      expect(result.totalEconomicResultCents, isNull);
    });

    test('não usa cotação de tipo incompatível para estimar posição', () {
      final result = InvestmentPerformanceCalculator.calculate(
        positions: <InvestmentPosition>[position()],
        quotes: <InvestmentQuote>[quote(type: TrackedInvestmentAssetType.fii)],
        receivedIncomeCents: 0,
        referenceInstant: captured,
      );
      expect(result.positions.single.isQuoted, isFalse);
      expect(result.estimatedMarketValueCents, isNull);
    });

    test('não usa snapshot vencido como valor atual', () {
      final result = InvestmentPerformanceCalculator.calculate(
        positions: <InvestmentPosition>[position()],
        quotes: <InvestmentQuote>[quote()],
        receivedIncomeCents: 0,
        referenceInstant: captured.add(const Duration(minutes: 21)),
      );
      expect(result.quotedAssetCount, 0);
      expect(result.totalEconomicResultCents, isNull);
    });

    test(
      'preserva resultado realizado de posição encerrada sem inventar valor de mercado',
      () {
        final result = InvestmentPerformanceCalculator.calculate(
          positions: <InvestmentPosition>[position(quantity: 0, realized: 123)],
          quotes: const <InvestmentQuote>[],
          receivedIncomeCents: 0,
          referenceInstant: captured,
        );
        expect(result.totalAssetCount, 0);
        expect(result.estimatedMarketValueCents, 0);
        expect(result.realizedResultCents, 123);
        expect(result.totalEconomicResultCents, 123);
      },
    );
  });
}
