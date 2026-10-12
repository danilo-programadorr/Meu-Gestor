enum MarketNewsCategory {
  market('market', 'Mercado'),
  economy('economy', 'Economia'),
  international('international', 'Internacional');

  const MarketNewsCategory(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static MarketNewsCategory fromStorage(String value) => values.firstWhere(
    (MarketNewsCategory category) => category.storageValue == value,
    orElse: () => throw const MarketNewsFailure(
      code: 'news_category_invalid',
      safeMessage: 'A categoria de notícias não pôde ser validada.',
    ),
  );
}

final class MarketNewsArticle {
  MarketNewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.articleUrl,
    this.imageUrl,
    required this.publishedAt,
  }) {
    if (!_identifier.hasMatch(id) ||
        title.trim() != title ||
        title.isEmpty ||
        title.length > 220 ||
        source.trim() != source ||
        source.isEmpty ||
        source.length > 120 ||
        !_isSafeArticleUrl(articleUrl) ||
        (imageUrl != null && !_isSafeArticleUrl(imageUrl!))) {
      throw const MarketNewsFailure(
        code: 'news_article_invalid',
        safeMessage: 'Uma notícia recebida não pôde ser validada.',
      );
    }
  }

  static final RegExp _identifier = RegExp(r'^[A-Za-z0-9_-]{8,128}$');

  final String id;
  final String title;
  final String source;
  final Uri articleUrl;
  final Uri? imageUrl;
  final DateTime publishedAt;

  static bool _isSafeArticleUrl(Uri value) =>
      value.scheme == 'https' &&
      value.host.isNotEmpty &&
      value.userInfo.isEmpty &&
      value.toString().length <= 2048;
}

final class MarketNewsFeed {
  MarketNewsFeed({
    required this.category,
    required this.provider,
    required this.fetchedAt,
    required this.staleAfter,
    required List<MarketNewsArticle> articles,
  }) : articles = List<MarketNewsArticle>.unmodifiable(articles) {
    if (provider != 'marketaux' ||
        !staleAfter.isAfter(fetchedAt) ||
        articles.length > 3 ||
        articles
                .map((MarketNewsArticle article) => article.id)
                .toSet()
                .length !=
            articles.length ||
        articles.any(
          (MarketNewsArticle article) => article.publishedAt.isAfter(
            fetchedAt.toUtc().add(const Duration(minutes: 5)),
          ),
        )) {
      throw const MarketNewsFailure(
        code: 'news_feed_invalid',
        safeMessage: 'O feed de notícias não pôde ser validado.',
      );
    }
  }

  final MarketNewsCategory category;
  final String provider;
  final DateTime fetchedAt;
  final DateTime staleAfter;
  final List<MarketNewsArticle> articles;

  bool isStaleAt(DateTime instant) => !instant.toUtc().isBefore(staleAfter);
}

final class MarketNewsReadResult {
  const MarketNewsReadResult({
    required this.feeds,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final Map<MarketNewsCategory, MarketNewsFeed> feeds;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class MarketNewsRepository {
  Future<MarketNewsReadResult> readFeeds({required bool serverOnly});
}

final class MarketNewsFailure implements Exception {
  const MarketNewsFailure({required this.code, required this.safeMessage});

  final String code;
  final String safeMessage;
}
