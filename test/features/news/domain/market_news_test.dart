import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';

void main() {
  final DateTime fetchedAt = DateTime.utc(2026, 10, 11, 15);

  MarketNewsArticle article({
    String id = 'article_12345678',
    String title = 'Mercado acompanha a decisão de juros',
    String url = 'https://example.com/noticia',
    String? imageUrl,
    DateTime? publishedAt,
  }) => MarketNewsArticle(
    id: id,
    title: title,
    source: 'example.com',
    articleUrl: Uri.parse(url),
    imageUrl: imageUrl == null ? null : Uri.parse(imageUrl),
    publishedAt: publishedAt ?? fetchedAt.subtract(const Duration(minutes: 20)),
  );

  test('aceita até três matérias HTTPS por categoria', () {
    final MarketNewsFeed feed = MarketNewsFeed(
      category: MarketNewsCategory.market,
      provider: 'marketaux',
      fetchedAt: fetchedAt,
      staleAfter: fetchedAt.add(const Duration(hours: 3)),
      articles: <MarketNewsArticle>[
        article(),
        article(id: 'article_22345678'),
        article(id: 'article_32345678'),
      ],
    );

    expect(feed.articles, hasLength(3));
    expect(feed.isStaleAt(fetchedAt.add(const Duration(hours: 2))), isFalse);
    expect(feed.isStaleAt(fetchedAt.add(const Duration(hours: 3))), isTrue);
  });

  test('rejeita URL insegura, duplicata e publicação futura', () {
    expect(
      () => article(imageUrl: 'http://cdn.example.com/noticia.jpg'),
      throwsA(isA<MarketNewsFailure>()),
    );
    expect(
      () => article(url: 'http://example.com/noticia'),
      throwsA(isA<MarketNewsFailure>()),
    );
    expect(
      () => MarketNewsFeed(
        category: MarketNewsCategory.economy,
        provider: 'marketaux',
        fetchedAt: fetchedAt,
        staleAfter: fetchedAt.add(const Duration(hours: 3)),
        articles: <MarketNewsArticle>[article(), article()],
      ),
      throwsA(isA<MarketNewsFailure>()),
    );
    expect(
      () => MarketNewsFeed(
        category: MarketNewsCategory.international,
        provider: 'marketaux',
        fetchedAt: fetchedAt,
        staleAfter: fetchedAt.add(const Duration(hours: 3)),
        articles: <MarketNewsArticle>[
          article(publishedAt: fetchedAt.add(const Duration(minutes: 6))),
        ],
      ),
      throwsA(isA<MarketNewsFailure>()),
    );
  });
}
