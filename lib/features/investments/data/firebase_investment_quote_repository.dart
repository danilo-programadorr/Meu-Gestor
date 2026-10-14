import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firestore_investment_quote_mapper.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

/// Leitor de snapshots globais. Não realiza consulta ao provedor, não escreve
/// e exige a leitura server-only quando o controlador pede confirmação.
final class FirebaseInvestmentQuoteRepository
    implements InvestmentQuoteRepository {
  FirebaseInvestmentQuoteRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  static const String collectionName = 'marketQuoteSnapshots';
  static const String historyCollectionName = 'marketQuoteHistory';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maximumTickersPerRead = 50;

  final FirebaseFirestore _firestore;

  @override
  Future<InvestmentQuoteReadResult> readQuotes({
    required Iterable<String> tickers,
    required bool serverOnly,
  }) async {
    final List<String> normalized =
        tickers
            .map(TrackedInvestmentAsset.requireTicker)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (normalized.length > _maximumTickersPerRead) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Há ativos demais para consultar de uma vez.',
        code: 'market_quote_batch_limit',
      );
    }
    try {
      final GetOptions? options = serverOnly
          ? const GetOptions(source: Source.server)
          : null;
      final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
          await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
            normalized.map(
              (String ticker) => _firestore
                  .collection(collectionName)
                  .doc(ticker)
                  .get(options),
            ),
          ).timeout(_timeout);
      final List<InvestmentQuote> quotes = snapshots
          .where(
            (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
                snapshot.exists && snapshot.data() != null,
          )
          .map(
            (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
                FirestoreInvestmentQuoteMapper.fromMap(
                  data: snapshot.data()!,
                  documentId: snapshot.id,
                ),
          )
          .toList(growable: false);
      return InvestmentQuoteReadResult(
        quotes: quotes,
        isFromServer: !snapshots.any(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.metadata.isFromCache,
        ),
        hasPendingWrites: snapshots.any(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.metadata.hasPendingWrites,
        ),
      );
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage: 'Não foi possível consultar cotações confirmadas agora.',
        code: 'market_quote_server_read_failed',
      );
    }
  }

  @override
  Future<List<InvestmentQuote>> readQuoteHistory({
    required String ticker,
    required int maximumPoints,
    required bool serverOnly,
  }) async {
    final String normalized = TrackedInvestmentAsset.requireTicker(ticker);
    if (maximumPoints < 2 || maximumPoints > 120) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'O período solicitado para o histórico é inválido.',
        code: 'market_quote_history_limit_invalid',
      );
    }
    try {
      final Query<Map<String, dynamic>> query = _firestore
          .collection(historyCollectionName)
          .doc(normalized)
          .collection('quoteDays')
          .orderBy('observedAt', descending: true)
          .limit(maximumPoints);
      final QuerySnapshot<Map<String, dynamic>> result = await query
          .get(serverOnly ? const GetOptions(source: Source.server) : null)
          .timeout(_timeout);
      final List<InvestmentQuote> points =
          result.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                    FirestoreInvestmentQuoteMapper.fromHistoryMap(
                      data: document.data(),
                      ticker: normalized,
                    ),
              )
              .toList(growable: false)
            ..sort(
              (InvestmentQuote first, InvestmentQuote second) =>
                  first.observedAt.compareTo(second.observedAt),
            );
      return List<InvestmentQuote>.unmodifiable(points);
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage: 'Não foi possível consultar o histórico confirmado agora.',
        code: 'market_quote_history_server_read_failed',
      );
    }
  }
}
