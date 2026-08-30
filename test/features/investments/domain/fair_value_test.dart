import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/fair_value.dart';

void main() {
  test('Graham exige fundamentos, cotação, moeda e fonte compatíveis', () {
    final FairValueResult value = FairValueCalculator.calculate(
      FairValueSnapshot(
        kind: FairValueAssetKind.stock,
        currencyCode: 'BRL',
        sourceAt: DateTime.utc(2026, 8, 28),
        quoteCents: 1000,
        earningsPerShareCents: 100,
        bookValuePerShareCents: 400,
      ),
    );
    expect(value.status, FairValueStatus.available);
    expect(value.fairPriceCents, greaterThan(0));
    expect(value.theoreticalPotentialBasisPoints, isNotNull);
    expect(
      FairValueCalculator.calculate(null).status,
      FairValueStatus.unavailable,
    );
  });

  test('BDR, FII, atraso e moeda incompatível possuem estados honestos', () {
    final DateTime sourceAt = DateTime.utc(2026, 8, 28);
    expect(
      FairValueCalculator.calculate(
        FairValueSnapshot(
          kind: FairValueAssetKind.bdr,
          currencyCode: 'BRL',
          sourceAt: sourceAt,
          quoteCents: 100,
        ),
      ).status,
      FairValueStatus.bdrPendingNormalization,
    );
    final FairValueResult fii = FairValueCalculator.calculate(
      FairValueSnapshot(
        kind: FairValueAssetKind.fii,
        currencyCode: 'BRL',
        sourceAt: sourceAt,
        quoteCents: 90,
        netAssetValuePerShareCents: 100,
      ),
    );
    expect(fii.status, FairValueStatus.available);
    expect(fii.priceToBookBasisPoints, 9000);
    expect(fii.premiumDiscountBasisPoints, -1000);
    expect(
      FairValueCalculator.calculate(
        FairValueSnapshot(
          kind: FairValueAssetKind.stock,
          currencyCode: 'USD',
          sourceAt: sourceAt,
          quoteCents: 100,
        ),
      ).status,
      FairValueStatus.incompatible,
    );
    expect(
      FairValueCalculator.calculate(
        FairValueSnapshot(
          kind: FairValueAssetKind.stock,
          currencyCode: 'BRL',
          sourceAt: sourceAt,
          quoteCents: 100,
          isStale: true,
        ),
      ).status,
      FairValueStatus.stale,
    );
  });
}
