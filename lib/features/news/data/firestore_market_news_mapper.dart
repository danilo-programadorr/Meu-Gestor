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
  static const Set<String> _articleFieldsV1 = <String>{
    'id',
    'title',
    'source',
    'articleUrl',
    'publishedAt',
  };
  static const Set<String> _articleFieldsV2 = <String>{
    ..._articleFieldsV1,
    'imageUrl',
  };

  static MarketNewsFeed fromMap({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    try {
      if (data.keys.toSet().difference(_feedFields).isNotEmpty ||
          _feedFields.difference(data.keys.toSet()).isNotEmpty ||
          data['schemaVersion'] is! int ||
          !<int>{1, 2}.contains(data['schemaVersion']) ||
          data['category'] != documentId ||
          data['articles'] is! List<Object?>) {
        throw StateError('news_feed_contract_invalid');
      }
      final MarketNewsCategory category = MarketNewsCategory.fromStorage(
        _string(data, 'category'),
      );
      final List<MarketNewsArticle> articles =
          (data['articles'] as List<Object?>)
              .map(
                (Object? value) => _article(
                  value,
                  schemaVersion: data['schemaVersion'] as int,
                ),
              )
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

  static MarketNewsArticle _article(
    Object? value, {
    required int schemaVersion,
  }) {
    final Set<String> expectedFields = schemaVersion == 2
        ? _articleFieldsV2
        : _articleFieldsV1;
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference(expectedFields).isNotEmpty ||
        expectedFields.difference(value.keys.toSet()).isNotEmpty) {
      throw StateError('news_article_contract_invalid');
    }
    return MarketNewsArticle(
      id: _string(value, 'id'),
      title: _string(value, 'title'),
      source: _string(value, 'source'),
      articleUrl: _safeHttpsUri(value, 'articleUrl'),
      imageUrl: schemaVersion == 2 ? _optionalUri(value, 'imageUrl') : null,
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

  static Uri? _optionalUri(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value == null) return null;
    if (value is! String) throw StateError('news_uri_invalid');
    return _parseSafeHttpsUri(value);
  }

  /// URLs externas são tratadas como dados não confiáveis. Somente HTTPS
  /// absoluto, sem credenciais embutidas, pode alcançar o launcher ou imagem.
  static Uri _safeHttpsUri(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) throw StateError('news_uri_invalid');
    return _parseSafeHttpsUri(value);
  }

  static Uri _parseSafeHttpsUri(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (value.length > 2048 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError('news_uri_invalid');
    }
    return uri;
  }
}
