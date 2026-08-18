import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

/// Converte somente snapshots globais já processados pelo backend. O cliente
/// nunca cria, completa ou corrige este contrato.
abstract final class FirestoreInvestmentQuoteMapper {
  static const Set<String> fieldNames = <String>{
    'ticker',
    'assetType',
    'currencyCode',
    'market',
    'source',
    'priceScaled',
    'variationBasisPoints',
    'observedAt',
    'capturedAt',
    'declaredDelaySeconds',
    'staleAfter',
    'status',
    'schemaVersion',
  };

  static InvestmentQuote fromMap({
    required Map<String, dynamic> data,
    required String documentId,
  }) {
    try {
      final Set<String> actual = data.keys.toSet();
      if (actual.difference(fieldNames).isNotEmpty ||
          fieldNames.difference(actual).isNotEmpty ||
          _string(data, 'ticker') != documentId ||
          _integer(data, 'schemaVersion') != 1) {
        throw StateError('invalid_market_quote_contract');
      }
      return InvestmentQuote(
        ticker: _string(data, 'ticker'),
        assetType: TrackedInvestmentAssetType.fromStorage(
          _string(data, 'assetType'),
        ),
        currencyCode: _string(data, 'currencyCode'),
        market: InvestmentQuoteMarket.fromStorage(_string(data, 'market')),
        unitPriceScaled: _integer(data, 'priceScaled'),
        variationBasisPoints: _nullableInteger(data, 'variationBasisPoints'),
        observedAt: _timestamp(data, 'observedAt'),
        capturedAt: _timestamp(data, 'capturedAt'),
        declaredDelay: Duration(
          seconds: _integer(data, 'declaredDelaySeconds'),
        ),
        staleAfter: _timestamp(data, 'staleAfter'),
        availability: InvestmentQuoteAvailability.values.byName(
          _string(data, 'status'),
        ),
        source: _string(data, 'source'),
      );
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'Uma cotação confirmada não pôde ser validada.',
        code: 'market_quote_conversion_failed',
      );
    }
  }

  static String _string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) throw StateError('invalid_quote_string');
    return value;
  }

  static int _integer(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! int) throw StateError('invalid_quote_integer');
    return value;
  }

  static int? _nullableInteger(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) return null;
    if (value is! int) throw StateError('invalid_quote_nullable_integer');
    return value;
  }

  static DateTime _timestamp(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! Timestamp) throw StateError('invalid_quote_timestamp');
    return value.toDate().toUtc();
  }
}
