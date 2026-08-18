import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

/// Situação declarada de uma cotação atrasada. Nenhum estado infere preço.
enum InvestmentQuoteAvailability {
  available,
  delayed,
  marketClosed,
  unavailable,
  invalid,
  corporateActionPossible,
}

/// Mercado da fonte de preço. Esta primeira versão aceita apenas B3 em BRL.
enum InvestmentQuoteMarket {
  b3;

  static InvestmentQuoteMarket fromStorage(String value) => switch (value) {
    'B3' => InvestmentQuoteMarket.b3,
    _ => throw ArgumentError.value(value, 'value', 'Mercado não suportado.'),
  };

  String get storageValue => 'B3';
}

/// Um snapshot global, em BRL, que nunca pertence a uma pessoa ou carteira.
final class InvestmentQuote {
  InvestmentQuote({
    required String ticker,
    required this.assetType,
    required this.currencyCode,
    required this.market,
    required this.unitPriceScaled,
    required this.variationBasisPoints,
    required this.observedAt,
    required this.capturedAt,
    required this.declaredDelay,
    required this.staleAfter,
    required this.availability,
    required this.source,
  }) : ticker = TrackedInvestmentAsset.requireTicker(ticker) {
    _validate();
  }

  final String ticker;
  final TrackedInvestmentAssetType assetType;
  final String currencyCode;
  final InvestmentQuoteMarket market;
  final int unitPriceScaled;
  final int? variationBasisPoints;
  final DateTime observedAt;
  final DateTime capturedAt;
  final Duration declaredDelay;
  final DateTime staleAfter;
  final InvestmentQuoteAvailability availability;

  /// Rótulo do provedor, nunca chave, URL privada ou credencial.
  final String source;

  bool get hasPrice =>
      availability == InvestmentQuoteAvailability.available ||
      availability == InvestmentQuoteAvailability.delayed ||
      availability == InvestmentQuoteAvailability.marketClosed;

  bool isStaleAt(DateTime instant) => !instant.toUtc().isBefore(staleAfter);

  void _validate() {
    if (currencyCode != TrackedInvestmentAsset.supportedCurrencyCode ||
        source.trim().isEmpty ||
        source.trim().length > 80) {
      _invalid('investment_quote_source_invalid');
    }
    if (declaredDelay.isNegative ||
        !staleAfter.toUtc().isAfter(capturedAt.toUtc())) {
      _invalid('investment_quote_temporal_invalid');
    }
    if (hasPrice) {
      if (unitPriceScaled <= 0 ||
          unitPriceScaled > InvestmentScale.maximumUnitPriceScaled ||
          variationBasisPoints == null ||
          variationBasisPoints! < -1000000 ||
          variationBasisPoints! > 1000000 ||
          observedAt.toUtc().isAfter(capturedAt.toUtc())) {
        _invalid('investment_quote_value_invalid');
      }
      return;
    }
    if (unitPriceScaled != 0 || variationBasisPoints != null) {
      _invalid('investment_quote_unavailable_with_price');
    }
  }

  Never _invalid(String code) => throw InvestmentFailure(
    kind: InvestmentFailureKind.incompatible,
    safeMessage: 'A cotação recebida não pôde ser validada.',
    code: code,
  );
}

/// Resultado explícito de consulta; ausência não equivale a preço zero.
final class InvestmentQuoteReadResult {
  const InvestmentQuoteReadResult({
    required this.quotes,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<InvestmentQuote> quotes;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class InvestmentQuoteRepository {
  /// Lê somente snapshots globais já verificados. Não consulta provedores.
  Future<InvestmentQuoteReadResult> readQuotes({
    required Iterable<String> tickers,
    required bool serverOnly,
  });
}
