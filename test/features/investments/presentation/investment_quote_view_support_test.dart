import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_quote_view_support.dart';

void main() {
  test('identifica fechamento válido e mantém vencimento explícito', () {
    final DateTime capturedAt = DateTime.utc(2026, 10, 16, 21, 30);
    final InvestmentQuote quote = InvestmentQuote(
      ticker: 'PETR4',
      assetType: TrackedInvestmentAssetType.stock,
      currencyCode: 'BRL',
      market: InvestmentQuoteMarket.b3,
      unitPriceScaled: 35000000,
      variationBasisPoints: 100,
      observedAt: DateTime.utc(2026, 10, 16, 20, 55),
      capturedAt: capturedAt,
      declaredDelay: const Duration(minutes: 30),
      staleAfter: DateTime.utc(2026, 10, 19, 13, 45),
      availability: InvestmentQuoteAvailability.marketClosed,
      source: 'fixture',
    );

    expect(
      InvestmentQuoteViewSupport.availability(quote, capturedAt),
      'Último fechamento',
    );
    expect(
      InvestmentQuoteViewSupport.availability(
        quote,
        DateTime.utc(2026, 10, 19, 13, 45),
      ),
      'Cotação vencida',
    );
  });
}
