import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';

/// Placeholder explícito até existir um backend autorizado de snapshots globais.
/// Não consulta rede e nunca inventa uma cotação para preencher a interface.
final class UnavailableInvestmentQuoteRepository
    implements InvestmentQuoteRepository {
  const UnavailableInvestmentQuoteRepository();

  @override
  Future<InvestmentQuoteReadResult> readQuotes({
    required Iterable<String> tickers,
    required bool serverOnly,
  }) async => const InvestmentQuoteReadResult(
    quotes: <InvestmentQuote>[],
    isFromServer: false,
    hasPendingWrites: false,
  );
}
