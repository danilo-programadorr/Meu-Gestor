import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/news/data/market_news_providers.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';
import 'package:meu_gestor_financeiro/features/news/presentation/pages/market_news_page.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 10, 11, 15);

  testWidgets('exibe somente Mercado, Economia e Internacional', (
    WidgetTester tester,
  ) async {
    await _pump(tester, now: now, result: _result(now));

    expect(find.text('Notícias'), findsOneWidget);
    expect(find.text('Mercado'), findsWidgets);
    expect(find.text('Economia'), findsOneWidget);
    expect(find.text('Internacional'), findsOneWidget);
    expect(find.text('Política'), findsNothing);
    expect(find.text('Mercado acompanha os juros'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('news-thumbnail-article_12345678')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('news-category-economy')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inflação desacelera'), findsOneWidget);
  });

  testWidgets('diferencia cobertura parcial e categoria ausente', (
    WidgetTester tester,
  ) async {
    final MarketNewsReadResult base = _result(now);
    await _pump(
      tester,
      now: now,
      result: MarketNewsReadResult(
        feeds: <MarketNewsCategory, MarketNewsFeed>{
          MarketNewsCategory.market: base.feeds[MarketNewsCategory.market]!,
        },
        isFromServer: true,
        hasPendingWrites: false,
      ),
    );

    expect(find.textContaining('cobertura parcial'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('news-category-international')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Internacional indisponível'), findsOneWidget);
  });

  testWidgets('bloqueia cache como confirmação e suporta tela estreita', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      now: now,
      result: const MarketNewsReadResult(
        feeds: <MarketNewsCategory, MarketNewsFeed>{},
        isFromServer: false,
        hasPendingWrites: false,
      ),
      dark: true,
      textScale: 1.4,
    );

    expect(find.text('Notícias indisponíveis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required DateTime now,
  required MarketNewsReadResult result,
  bool dark = false,
  double textScale = 1,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: '/noticias',
    routes: <RouteBase>[
      GoRoute(path: '/noticias', builder: (_, _) => const MarketNewsPage()),
      GoRoute(
        path: '/inicio',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marketNewsRepositoryProvider.overrideWithValue(
          _FakeMarketNewsRepository(result),
        ),
        marketNewsClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MarketNewsReadResult _result(DateTime now) {
  MarketNewsFeed feed(MarketNewsCategory category, String id, String title) =>
      MarketNewsFeed(
        category: category,
        provider: 'marketaux',
        fetchedAt: now.subtract(const Duration(minutes: 20)),
        staleAfter: now.add(const Duration(hours: 2)),
        articles: <MarketNewsArticle>[
          MarketNewsArticle(
            id: id,
            title: title,
            source: 'example.com',
            articleUrl: Uri.parse('https://example.com/$id'),
            imageUrl: category == MarketNewsCategory.market
                ? Uri.parse('https://cdn.example.com/$id.jpg')
                : null,
            publishedAt: now.subtract(const Duration(minutes: 30)),
          ),
        ],
      );
  return MarketNewsReadResult(
    feeds: <MarketNewsCategory, MarketNewsFeed>{
      MarketNewsCategory.market: feed(
        MarketNewsCategory.market,
        'article_12345678',
        'Mercado acompanha os juros',
      ),
      MarketNewsCategory.economy: feed(
        MarketNewsCategory.economy,
        'article_22345678',
        'Inflação desacelera',
      ),
      MarketNewsCategory.international: feed(
        MarketNewsCategory.international,
        'article_32345678',
        'Mercados globais avançam',
      ),
    },
    isFromServer: true,
    hasPendingWrites: false,
  );
}

final class _FakeMarketNewsRepository implements MarketNewsRepository {
  const _FakeMarketNewsRepository(this.result);

  final MarketNewsReadResult result;

  @override
  Future<MarketNewsReadResult> readFeeds({required bool serverOnly}) async {
    expect(serverOnly, isTrue);
    return result;
  }
}
