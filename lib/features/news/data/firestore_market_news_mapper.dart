import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';

/// Converte somente snapshots globais criados pelo backend. Conteúdo extra,
/// URL insegura ou categoria divergente invalida o documento inteiro.
abstract final class FirestoreMarketNewsMapper {
  static const Set<String> _feedFields = <String>{
    'category',
    'provider',
    'fetchedAt',
    'staleAfter',
    'articles',
    'schemaVersion',
  };
  static const Set<String> _articleFields = <String>{
    'id',
    'title',
    'source',
    'articleUrl',
    'publishedAt',
  };

  static MarketNewsFeed fromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      if (data.keys.toSet().difference(_feedFields).isNotEmpty ||
          _feedFields.difference(data.keys.toSet()).isNotEmpty ||
          data['schemaVersion'] != 1 ||
          data['category'] != documentId ||
          data['articles'] is! List<Object?>) {
        throw StateError('news_feed_contract_invalid');
      }
      final MarketNewsCategory category = MarketNewsCategory.fromStorage(
        _string(data, 'category'),
      );
      final List<MarketNewsArticle> articles =
          (data['articles'] as List<Object?>)
              .map(_article)
              .toList(growable: false);
      return MarketNewsFeed(
        category: category,
        provider: _string(data, 'provider'),
        fetchedAt: _timestamp(data, 'fetchedAt'),
        staleAfter: _timestamp(data, 'staleAfter'),
        articles: articles,
      );
    } on MarketNewsFailure {
      rethrow;
    } on Object {
      throw const MarketNewsFailure(
        code: 'news_feed_conversion_failed',
        safeMessage: 'As notícias confirmadas não puderam ser validadas.',
      );
    }
  }

  static MarketNewsArticle _article(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(_articleFields).isNotEmpty ||
        _articleFields.difference(value.keys.toSet()).isNotEmpty) {
      throw StateError('news_article_contract_invalid');
    }
    return MarketNewsArticle(
      id: _string(value, 'id'),
      title: _string(value, 'title'),
      source: _string(value, 'source'),
      articleUrl: Uri.parse(_string(value, 'articleUrl')),
      publishedAt: _timestamp(value, 'publishedAt'),
    );
  }

  static String _string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) throw StateError('news_string_invalid');
    return value;
  }

  static DateTime _timestamp(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! Timestamp) throw StateError('news_timestamp_invalid');
    return value.toDate().toUtc();
  }
}
