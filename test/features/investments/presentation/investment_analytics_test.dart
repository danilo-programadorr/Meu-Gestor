import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_analytics.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('InvestmentAnalytics', () {
    test('evolução agrega compras e vendas reais e ignora anuladas', () {
      final List<InvestmentOperation> operations = <InvestmentOperation>[
        _operation(
          id: 'buy-1',
          date: DateTime.utc(2026, 6, 5),
          kind: InvestmentOperationKind.buy,
          quantity: '2',
          price: '100',
          feesCents: 100,
        ),
        _operation(
          id: 'sell-1',
          date: DateTime.utc(2026, 7, 5),
          kind: InvestmentOperationKind.sell,
          quantity: '1',
          price: '120',
          feesCents: 50,
          previousId: 'buy-1',
          previousDate: DateTime.utc(2026, 6, 5),
        ),
        _operation(
          id: 'voided',
          date: DateTime.utc(2026, 8, 1),
          kind: InvestmentOperationKind.buy,
          quantity: '10',
          price: '999',
          feesCents: 0,
          previousId: 'sell-1',
          previousDate: DateTime.utc(2026, 7, 5),
          isVoided: true,
        ),
      ];

      final List<InvestmentEvolutionBucket> buckets =
          InvestmentAnalytics.evolution(
            operations: operations,
            portfolioId: 'portfolio-1',
            period: InvestmentPeriodFilter.last3Months,
            now: DateTime.utc(2026, 8, 9, 12),
          );

      expect(buckets.map((value) => value.label), <String>[
        '06/26',
        '07/26',
        '08/26',
      ]);
      expect(buckets[0].buyCents, 20100);
      expect(buckets[1].sellCents, 11950);
      expect(buckets[2].buyCents, 0);
    });

    test('período todo agrega por ano quando a série seria muito longa', () {
      final List<InvestmentEvolutionBucket> buckets =
          InvestmentAnalytics.evolution(
            operations: <InvestmentOperation>[
              _operation(
                id: 'old',
                date: DateTime.utc(2023, 1, 1),
                kind: InvestmentOperationKind.buy,
                quantity: '1',
                price: '10',
                feesCents: 0,
              ),
              _operation(
                id: 'new',
                date: DateTime.utc(2026, 8, 1),
                kind: InvestmentOperationKind.buy,
                quantity: '1',
                price: '20',
                feesCents: 0,
                previousId: 'old',
                previousDate: DateTime.utc(2023, 1, 1),
              ),
            ],
            portfolioId: 'portfolio-1',
            period: InvestmentPeriodFilter.all,
            now: DateTime.utc(2026, 8, 9),
          );

      expect(buckets.map((value) => value.label), <String>[
        '2023',
        '2024',
        '2025',
        '2026',
      ]);
      expect(buckets.first.buyCents, 1000);
      expect(buckets.last.buyCents, 2000);
    });

    test('alocação usa custo das posições abertas e percentuais reais', () {
      final InvestmentProjection projection = InvestmentProjection(
        positions: <InvestmentPosition>[
          _position(
            ticker: 'PETR4',
            type: TrackedInvestmentAssetType.stock,
            costCents: 30000,
            quantityScaled: InvestmentQuantity.parsePtBr('10').scaled,
          ),
          _position(
            ticker: 'HGLG11',
            type: TrackedInvestmentAssetType.fii,
            costCents: 70000,
            quantityScaled: InvestmentQuantity.parsePtBr('2').scaled,
          ),
          _position(
            ticker: 'VALE3',
            type: TrackedInvestmentAssetType.stock,
            costCents: 0,
            quantityScaled: 0,
          ),
        ],
        totalCostCents: 100000,
        totalRealizedResultCents: 0,
      );

      final List<InvestmentAllocationSlice> classes =
          InvestmentAnalytics.allocationByClass(projection);
      final List<InvestmentAllocationSlice> assets =
          InvestmentAnalytics.allocationByAsset(projection);

      expect(classes, hasLength(2));
      expect(
        classes.firstWhere((value) => value.label == 'Ação').fraction,
        0.3,
      );
      expect(
        classes
            .firstWhere((value) => value.label == 'Fundo imobiliário')
            .fraction,
        0.7,
      );
      expect(assets.map((value) => value.label), <String>['HGLG11', 'PETR4']);
    });

    test('busca, tipo e desempate de ordenação são determinísticos', () {
      final List<InvestmentPosition> positions = <InvestmentPosition>[
        _position(
          ticker: 'VALE3',
          type: TrackedInvestmentAssetType.stock,
          costCents: 10000,
          quantityScaled: 1,
          name: 'Vale ON',
        ),
        _position(
          ticker: 'PETR4',
          type: TrackedInvestmentAssetType.stock,
          costCents: 10000,
          quantityScaled: 1,
          name: 'Petrobras PN',
        ),
        _position(
          ticker: 'HGLG11',
          type: TrackedInvestmentAssetType.fii,
          costCents: 20000,
          quantityScaled: 1,
          name: 'CSHG Logística',
        ),
      ];

      expect(
        InvestmentAnalytics.filterPositions(
          positions: positions,
          query: '',
          filter: InvestmentAssetFilter.all,
          sort: InvestmentPositionSort.highestCost,
        ).map((value) => value.asset.ticker),
        <String>['HGLG11', 'PETR4', 'VALE3'],
      );
      expect(
        InvestmentAnalytics.filterPositions(
          positions: positions,
          query: 'vale',
          filter: InvestmentAssetFilter.stocks,
          sort: InvestmentPositionSort.ticker,
        ).single.asset.ticker,
        'VALE3',
      );
    });
  });
}

InvestmentOperation _operation({
  required String id,
  required DateTime date,
  required InvestmentOperationKind kind,
  required String quantity,
  required String price,
  required int feesCents,
  String? previousId,
  DateTime? previousDate,
  bool isVoided = false,
}) {
  final DateTime occurredAt = InvestmentOperation.fromCalendarDate(date);
  return InvestmentOperation(
    id: id,
    ownerId: 'owner',
    portfolioId: 'portfolio-1',
    assetId: 'asset-1',
    previousOperationId: previousId,
    previousOperationAt: previousDate == null
        ? null
        : InvestmentOperation.fromCalendarDate(previousDate),
    kind: kind,
    occurredAt: occurredAt,
    quantityScaled: InvestmentQuantity.parsePtBr(quantity).scaled,
    unitPriceScaled: InvestmentUnitPrice.parsePtBr(price).scaled,
    feesCents: feesCents,
    notes: '',
    isVoided: isVoided,
    voidedAt: isVoided ? occurredAt.add(const Duration(hours: 2)) : null,
    mutationId: 'mutation-$id',
    createdAt: occurredAt.add(const Duration(hours: 1)),
    updatedAt: occurredAt.add(const Duration(hours: 1)),
    schemaVersion: 1,
    revision: 1,
  );
}

InvestmentPosition _position({
  required String ticker,
  required TrackedInvestmentAssetType type,
  required int costCents,
  required int quantityScaled,
  String? name,
}) {
  final DateTime now = DateTime.utc(2026, 8, 1);
  return InvestmentPosition(
    asset: TrackedInvestmentAsset(
      id: 'portfolio-1__$ticker',
      ownerId: 'owner',
      portfolioId: 'portfolio-1',
      ticker: ticker,
      name: name ?? ticker,
      type: type,
      currencyCode: 'BRL',
      currentQuantityScaled: quantityScaled,
      lastOperationId: null,
      lastOperationAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    ),
    quantityScaled: quantityScaled,
    totalCostCents: costCents,
    averageUnitPriceScaled: 0,
    realizedResultCents: 0,
    activeOperationCount: 0,
  );
}
