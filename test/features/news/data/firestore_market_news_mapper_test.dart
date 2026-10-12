import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/news/data/firestore_market_news_mapper.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';

void main() {
  final Timestamp fetchedAt = Timestamp.fromDate(
    DateTime.utc(2026, 10, 11, 15),
  );

  Map<String, dynamic> feed({
    Map<String, dynamic> overrides = const {},
  }) => <String, dynamic>{
    'category': 'market',
    'provider': 'marketaux',
    'fetchedAt': fetchedAt,
    'staleAfter': Timestamp.fromDate(DateTime.utc(2026, 10, 11, 18)),
    'articles': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'article_12345678',
        'title': 'Mercado acompanha a decisão de juros',
        'source': 'example.com',
        'articleUrl': 'https://example.com/noticia',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 11, 14, 30)),
      },
    ],
    'schemaVersion': 1,
    ...overrides,
  };

  test('converte contrato exato do backend', () {
    final MarketNewsFeed result = FirestoreMarketNewsMapper.fromMap(
      documentId: 'market',
      data: feed(),
    );

    expect(result.category, MarketNewsCategory.market);
    expect(result.provider, 'marketaux');
    expect(result.articles.single.source, 'example.com');
  });

  test('rejeita documento divergente ou com campo adicional', () {
    expect(
      () => FirestoreMarketNewsMapper.fromMap(
        documentId: 'economy',
        data: feed(),
      ),
      throwsA(isA<MarketNewsFailure>()),
    );
    expect(
      () => FirestoreMarketNewsMapper.fromMap(
        documentId: 'market',
        data: feed(overrides: <String, dynamic>{'token': 'forbidden'}),
      ),
      throwsA(isA<MarketNewsFailure>()),
    );
  });
}
