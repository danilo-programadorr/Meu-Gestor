import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firestore_investment_quote_mapper.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';

void main() {
  final Timestamp observed = Timestamp.fromDate(DateTime.utc(2026, 8, 18, 12));
  final Timestamp captured = Timestamp.fromDate(
    DateTime.utc(2026, 8, 18, 12, 15),
  );

  Map<String, dynamic> quote({Map<String, dynamic> overrides = const {}}) =>
      <String, dynamic>{
        'ticker': 'PETR4',
        'assetType': 'stock',
        'currencyCode': 'BRL',
        'market': 'B3',
        'source': 'brapi',
        'priceScaled': 31450000,
        'variationBasisPoints': -123,
        'observedAt': observed,
        'capturedAt': captured,
        'declaredDelaySeconds': 900,
        'staleAfter': Timestamp.fromDate(DateTime.utc(2026, 8, 18, 12, 45)),
        'status': 'delayed',
        'schemaVersion': 1,
        ...overrides,
      };

  test('mapper aceita apenas o snapshot global B3 estrito', () {
    final InvestmentQuote mapped = FirestoreInvestmentQuoteMapper.fromMap(
      data: quote(),
      documentId: 'PETR4',
    );
    expect(mapped.market, InvestmentQuoteMarket.b3);
    expect(mapped.unitPriceScaled, 31450000);
    expect(mapped.declaredDelay, const Duration(minutes: 15));
  });

  test('mapper rejeita documento, schema, campo e timestamp incompatíveis', () {
    expect(
      () => FirestoreInvestmentQuoteMapper.fromMap(
        data: quote(),
        documentId: 'HGLG11',
      ),
      throwsException,
    );
    expect(
      () => FirestoreInvestmentQuoteMapper.fromMap(
        data: quote(overrides: <String, dynamic>{'schemaVersion': 2}),
        documentId: 'PETR4',
      ),
      throwsException,
    );
    expect(
      () => FirestoreInvestmentQuoteMapper.fromMap(
        data: quote(overrides: <String, dynamic>{'extra': true}),
        documentId: 'PETR4',
      ),
      throwsException,
    );
    expect(
      () => FirestoreInvestmentQuoteMapper.fromMap(
        data: quote(
          overrides: <String, dynamic>{'capturedAt': 'not-a-timestamp'},
        ),
        documentId: 'PETR4',
      ),
      throwsException,
    );
  });
}
