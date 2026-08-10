import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  group('projeção determinística da posição', () {
    test('incorpora taxas de compra no custo e calcula média móvel', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 1000000000, lastId: 'buy-1', lastDay: 1),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 1000000000,
            price: 10000000,
            fees: 100,
          ),
        ],
      );
      final InvestmentPosition position = result.positions.single;
      expect(position.totalCostCents, 10100);
      expect(position.averageUnitPriceScaled, 10100000);
      expect(position.realizedResultCents, 0);
    });

    test('combina compras sucessivas com preços diferentes', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 200000000, lastId: 'buy-2', lastDay: 2),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 100000000,
            price: 10000000,
          ),
          _operation(
            id: 'buy-2',
            kind: InvestmentOperationKind.buy,
            quantity: 100000000,
            price: 20000000,
            day: 2,
            previousId: 'buy-1',
            previousDay: 1,
          ),
        ],
      );
      expect(result.positions.single.totalCostCents, 3000);
      expect(result.positions.single.averageUnitPriceScaled, 15000000);
    });

    test('venda parcial usa mesmo custo médio e reduz taxas do resultado', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 600000000, lastId: 'sell-1', lastDay: 2),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 1000000000,
            price: 10000000,
            fees: 100,
          ),
          _operation(
            id: 'sell-1',
            kind: InvestmentOperationKind.sell,
            quantity: 400000000,
            price: 15000000,
            fees: 50,
            day: 2,
            previousId: 'buy-1',
            previousDay: 1,
          ),
        ],
      );
      final InvestmentPosition position = result.positions.single;
      expect(position.quantityScaled, 600000000);
      expect(position.totalCostCents, 6060);
      expect(position.averageUnitPriceScaled, 10100000);
      expect(position.realizedResultCents, 1910);
    });

    test('venda total zera custo sem perder resultado nem posição', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 0, lastId: 'sell-1', lastDay: 2),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 100000000,
            price: 10000000,
          ),
          _operation(
            id: 'sell-1',
            kind: InvestmentOperationKind.sell,
            quantity: 100000000,
            price: 12000000,
            day: 2,
            previousId: 'buy-1',
            previousDay: 1,
          ),
        ],
      );
      expect(result.positions.single.isClosed, isTrue);
      expect(result.positions.single.totalCostCents, 0);
      expect(result.positions.single.averageUnitPriceScaled, 0);
      expect(result.positions.single.realizedResultCents, 200);
    });

    test('ignora operação anulada na reconstrução', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 100000000, lastId: 'buy-1', lastDay: 1),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 100000000,
            price: 10000000,
          ),
          _operation(
            id: 'sell-void',
            kind: InvestmentOperationKind.sell,
            quantity: 100000000,
            price: 12000000,
            day: 2,
            previousId: 'buy-1',
            previousDay: 1,
            voided: true,
          ),
        ],
      );
      expect(result.positions.single.quantityScaled, 100000000);
      expect(result.positions.single.activeOperationCount, 1);
    });

    test('rejeita anulação que deixa operação posterior inconsistente', () {
      expect(
        () => InvestmentProjection.rebuild(
          assets: <TrackedInvestmentAsset>[
            _asset(quantity: 0, lastId: 'sell-1', lastDay: 2),
          ],
          operations: <InvestmentOperation>[
            _operation(
              id: 'buy-void',
              kind: InvestmentOperationKind.buy,
              quantity: 100000000,
              price: 10000000,
              voided: true,
            ),
            _operation(
              id: 'sell-1',
              kind: InvestmentOperationKind.sell,
              quantity: 100000000,
              price: 12000000,
              day: 2,
              previousId: 'buy-void',
              previousDay: 1,
            ),
          ],
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('ordena mesma data por criação e exige cadeia correspondente', () {
      final InvestmentProjection result = InvestmentProjection.rebuild(
        assets: <TrackedInvestmentAsset>[
          _asset(quantity: 0, lastId: 'sell-1', lastDay: 1),
        ],
        operations: <InvestmentOperation>[
          _operation(
            id: 'sell-1',
            kind: InvestmentOperationKind.sell,
            quantity: 100000000,
            price: 12000000,
            previousId: 'buy-1',
            previousDay: 1,
            createdHour: 13,
          ),
          _operation(
            id: 'buy-1',
            kind: InvestmentOperationKind.buy,
            quantity: 100000000,
            price: 10000000,
            createdHour: 12,
          ),
        ],
      );
      expect(result.positions.single.realizedResultCents, 200);
    });

    test(
      'rejeita cadeia anterior adulterada mesmo com quantidade coincidente',
      () {
        expect(
          () => InvestmentProjection.rebuild(
            assets: <TrackedInvestmentAsset>[
              _asset(quantity: 200000000, lastId: 'buy-2', lastDay: 2),
            ],
            operations: <InvestmentOperation>[
              _operation(
                id: 'buy-1',
                kind: InvestmentOperationKind.buy,
                quantity: 100000000,
                price: 10000000,
              ),
              _operation(
                id: 'buy-2',
                kind: InvestmentOperationKind.buy,
                quantity: 100000000,
                price: 10000000,
                day: 2,
                previousId: 'forged',
                previousDay: 1,
              ),
            ],
          ),
          throwsA(isA<InvestmentFailure>()),
        );
      },
    );

    test('rejeita venda histórica acima da posição', () {
      expect(
        () => InvestmentProjection.rebuild(
          assets: <TrackedInvestmentAsset>[_asset(quantity: 0)],
          operations: <InvestmentOperation>[
            _operation(
              id: 'sell-1',
              kind: InvestmentOperationKind.sell,
              quantity: 100000000,
              price: 10000000,
            ),
          ],
        ),
        throwsA(
          isA<InvestmentFailure>().having(
            (InvestmentFailure value) => value.kind,
            'kind',
            InvestmentFailureKind.insufficientPosition,
          ),
        ),
      );
    });

    test('rejeita projeção materializada divergente do histórico', () {
      expect(
        () => InvestmentProjection.rebuild(
          assets: <TrackedInvestmentAsset>[_asset(quantity: 1)],
          operations: const <InvestmentOperation>[],
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });
  });
}

TrackedInvestmentAsset _asset({
  required int quantity,
  String? lastId,
  int? lastDay,
}) => TrackedInvestmentAsset(
  id: 'portfolio-1__PETR4',
  ownerId: 'owner',
  portfolioId: 'portfolio-1',
  ticker: 'PETR4',
  name: 'Petrobras PN',
  type: TrackedInvestmentAssetType.stock,
  currencyCode: 'BRL',
  currentQuantityScaled: quantity,
  lastOperationId: lastId,
  lastOperationAt: lastDay == null ? null : DateTime.utc(2026, 8, lastDay, 3),
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
  schemaVersion: 1,
  revision: 1,
);

InvestmentOperation _operation({
  required String id,
  required InvestmentOperationKind kind,
  required int quantity,
  required int price,
  int fees = 0,
  int day = 1,
  String? previousId,
  int? previousDay,
  bool voided = false,
  int createdHour = 12,
}) => InvestmentOperation(
  id: id,
  ownerId: 'owner',
  portfolioId: 'portfolio-1',
  assetId: 'portfolio-1__PETR4',
  previousOperationId: previousId,
  previousOperationAt: previousDay == null
      ? null
      : DateTime.utc(2026, 8, previousDay, 3),
  kind: kind,
  occurredAt: DateTime.utc(2026, 8, day, 3),
  quantityScaled: quantity,
  unitPriceScaled: price,
  feesCents: fees,
  notes: '',
  isVoided: voided,
  voidedAt: voided ? DateTime.utc(2026, 8, 4) : null,
  mutationId: id,
  createdAt: DateTime.utc(2026, 8, day, createdHour),
  updatedAt: DateTime.utc(2026, 8, day, createdHour),
  schemaVersion: 1,
  revision: voided ? 2 : 1,
);
