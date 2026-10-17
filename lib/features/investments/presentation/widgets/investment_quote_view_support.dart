import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

/// Mantém os rótulos de mercado iguais no resumo, na lista e nos detalhes.
abstract final class InvestmentQuoteViewSupport {
  static InvestmentQuote? quoteFor(
    Iterable<InvestmentQuote> quotes,
    String ticker,
  ) {
    for (final InvestmentQuote quote in quotes) {
      if (quote.ticker == ticker) return quote;
    }
    return null;
  }

  static String price(InvestmentQuote quote, {required bool visible}) {
    if (!quote.hasPrice) return 'Indisponível';
    return visible
        ? 'R\$ ${InvestmentUnitPrice.fromScaled(quote.unitPriceScaled).formatPtBr()}'
        : '••••';
  }

  static String variation(InvestmentQuote quote, {required bool visible}) {
    if (!visible) return '••••';
    final int? basisPoints = quote.variationBasisPoints;
    if (basisPoints == null) return 'Indisponível';
    final String signal = basisPoints > 0
        ? '+'
        : basisPoints < 0
        ? '-'
        : '';
    final int absolute = basisPoints.abs();
    return '$signal${absolute ~/ 100},${(absolute % 100).toString().padLeft(2, '0')}%';
  }

  static String availability(InvestmentQuote quote, DateTime now) {
    if (quote.isStaleAt(now)) return 'Cotação vencida';
    return switch (quote.availability) {
      InvestmentQuoteAvailability.available => 'Disponível',
      InvestmentQuoteAvailability.delayed => 'Atrasada',
      InvestmentQuoteAvailability.marketClosed => 'Último fechamento',
      InvestmentQuoteAvailability.corporateActionPossible =>
        'Possível evento corporativo',
      InvestmentQuoteAvailability.invalid => 'Cotação inválida',
      InvestmentQuoteAvailability.unavailable => 'Cotação indisponível',
    };
  }

  static String observedAt(InvestmentQuote quote) =>
      DateFormat('dd/MM HH:mm', 'pt_BR').format(quote.observedAt.toLocal());
}
