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
        'imageUrl': 'https://cdn.example.com/noticia.jpg',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 11, 14, 30)),
      },
    ],
    'schemaVersion': 2,
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
    expect(
      result.articles.single.imageUrl,
      Uri.parse('https://cdn.example.com/noticia.jpg'),
    );
  });

  test('mantém leitura do schema anterior sem miniatura', () {
    final Map<String, dynamic> legacy = feed();
    legacy['schemaVersion'] = 1;
    legacy['articles'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'article_12345678',
        'title': 'Mercado acompanha a decisão de juros',
        'source': 'example.com',
        'articleUrl': 'https://example.com/noticia',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 11, 14, 30)),
      },
    ];

    final MarketNewsFeed result = FirestoreMarketNewsMapper.fromMap(
      documentId: 'market',
      data: legacy,
    );
    expect(result.articles.single.imageUrl, isNull);
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
    final Map<String, dynamic> missingImage = feed();
    missingImage['articles'] = <Map<String, dynamic>>[
      Map<String, dynamic>.from(
        (feed()['articles'] as List<Map<String, dynamic>>).single,
      )..remove('imageUrl'),
    ];
    expect(
      () => FirestoreMarketNewsMapper.fromMap(
        documentId: 'market',
        data: missingImage,
      ),
      throwsA(isA<MarketNewsFailure>()),
    );
  });

  test('rejeita URL não HTTPS, relativa ou com credenciais embutidas', () {
    for (final String unsafeUrl in <String>[
      'http://example.com/noticia',
      'javascript:alert(1)',
      '/noticia/relativa',
      'https://user:secret@example.com/noticia',
    ]) {
      final Map<String, dynamic> unsafe = feed();
      final Map<String, dynamic> article = Map<String, dynamic>.from(
        (unsafe['articles'] as List<Map<String, dynamic>>).single,
      )..['articleUrl'] = unsafeUrl;
      unsafe['articles'] = <Map<String, dynamic>>[article];
      expect(
        () => FirestoreMarketNewsMapper.fromMap(
          documentId: 'market',
          data: unsafe,
        ),
        throwsA(isA<MarketNewsFailure>()),
      );
    }
  });

  test('rejeita imagem externa que não usa HTTPS', () {
    final Map<String, dynamic> unsafe = feed();
    final Map<String, dynamic> article = Map<String, dynamic>.from(
      (unsafe['articles'] as List<Map<String, dynamic>>).single,
    )..['imageUrl'] = 'http://cdn.example.com/noticia.jpg';
    unsafe['articles'] = <Map<String, dynamic>>[article];

    expect(
      () =>
          FirestoreMarketNewsMapper.fromMap(documentId: 'market', data: unsafe),
      throwsA(isA<MarketNewsFailure>()),
    );
  });
}
