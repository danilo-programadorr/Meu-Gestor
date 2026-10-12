import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/news/data/firestore_market_news_mapper.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';

/// Lê três documentos globais conhecidos. O cliente não enumera a coleção,
/// não consulta o Marketaux e não escreve snapshots.
final class FirebaseMarketNewsRepository implements MarketNewsRepository {
  FirebaseMarketNewsRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  static const String collectionName = 'marketNewsFeeds';
  static const Duration _timeout = Duration(seconds: 12);

  final FirebaseFirestore _firestore;

  @override
  Future<MarketNewsReadResult> readFeeds({required bool serverOnly}) async {
    try {
      final GetOptions? options = serverOnly
          ? const GetOptions(source: Source.server)
          : null;
      final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
          await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
            MarketNewsCategory.values.map(
              (MarketNewsCategory category) => _firestore
                  .collection(collectionName)
                  .doc(category.storageValue)
                  .get(options),
            ),
          ).timeout(_timeout);
      final Map<MarketNewsCategory, MarketNewsFeed> feeds =
          <MarketNewsCategory, MarketNewsFeed>{};
      for (final DocumentSnapshot<Map<String, dynamic>> snapshot in snapshots) {
        final Map<String, dynamic>? data = snapshot.data();
        if (!snapshot.exists || data == null) continue;
        final MarketNewsFeed feed = FirestoreMarketNewsMapper.fromMap(
          documentId: snapshot.id,
          data: data,
        );
        feeds[feed.category] = feed;
      }
      return MarketNewsReadResult(
        feeds: Map<MarketNewsCategory, MarketNewsFeed>.unmodifiable(feeds),
        isFromServer: !snapshots.any(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.metadata.isFromCache,
        ),
        hasPendingWrites: snapshots.any(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.metadata.hasPendingWrites,
        ),
      );
    } on MarketNewsFailure {
      rethrow;
    } on Object {
      throw const MarketNewsFailure(
        code: 'news_server_read_failed',
        safeMessage: 'Não foi possível consultar notícias confirmadas agora.',
      );
    }
  }
}
