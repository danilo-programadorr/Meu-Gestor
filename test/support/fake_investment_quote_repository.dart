import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';

final class FakeInvestmentQuoteRepository implements InvestmentQuoteRepository {
  final List<InvestmentQuote> quotes = <InvestmentQuote>[];
  Object? nextFailure;
  int readCalls = 0;
  List<String> lastTickers = const <String>[];
  final Map<String, List<InvestmentQuote>> history =
      <String, List<InvestmentQuote>>{};

  @override
  Future<InvestmentQuoteReadResult> readQuotes({
    required Iterable<String> tickers,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    lastTickers = tickers.toList(growable: false)..sort();
    final Object? failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    final Set<String> requested = lastTickers.toSet();
    return InvestmentQuoteReadResult(
      quotes: quotes
          .where((InvestmentQuote quote) => requested.contains(quote.ticker))
          .toList(growable: false),
      isFromServer: true,
      hasPendingWrites: false,
    );
  }

  @override
  Future<List<InvestmentQuote>> readQuoteHistory({
    required String ticker,
    required int maximumPoints,
    required bool serverOnly,
  }) async => List<InvestmentQuote>.unmodifiable(
    (history[ticker] ?? const <InvestmentQuote>[]).take(maximumPoints),
  );
}
