import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/news/data/market_news_providers.dart';
import 'package:meu_gestor_financeiro/features/news/domain/market_news.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketNewsPage extends ConsumerStatefulWidget {
  const MarketNewsPage({super.key});

  @override
  ConsumerState<MarketNewsPage> createState() => _MarketNewsPageState();
}

class _MarketNewsPageState extends ConsumerState<MarketNewsPage> {
  MarketNewsCategory _category = MarketNewsCategory.market;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MarketNewsReadResult> result = ref.watch(
      marketNewsFeedsProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Notícias'),
        ),
        body: SafeArea(
          child: result.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando notícias',
              ),
            ),
            error: (Object _, StackTrace _) => _NewsUnavailable(
              onRetry: () => ref.invalidate(marketNewsFeedsProvider),
            ),
            data: _buildResult,
          ),
        ),
      ),
    );
  }

  Widget _buildResult(MarketNewsReadResult result) {
    if (!result.isFromServer || result.hasPendingWrites) {
      return _NewsUnavailable(
        onRetry: () => ref.invalidate(marketNewsFeedsProvider),
      );
    }
    final MarketNewsFeed? feed = result.feeds[_category];
    final DateTime now = ref.read(marketNewsClockProvider)().toUtc();
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketNewsFeedsProvider);
        await ref.read(marketNewsFeedsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.compactPageHorizontal,
          AppSpacing.md,
          AppSpacing.compactPageHorizontal,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          const _NewsNotice(),
          const SizedBox(height: AppSpacing.md),
          _CategorySelector(
            selected: _category,
            onSelected: (MarketNewsCategory value) =>
                setState(() => _category = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (feed == null || feed.articles.isEmpty)
            _CategoryUnavailable(
              category: _category,
              onRetry: () => ref.invalidate(marketNewsFeedsProvider),
            )
          else ...<Widget>[
            _FeedStatus(feed: feed, now: now),
            const SizedBox(height: AppSpacing.sm),
            for (final MarketNewsArticle article in feed.articles)
              _ArticleCard(
                article: article,
                category: feed.category,
                onOpen: () => _openArticle(article.articleUrl),
              ),
            if (feed.articles.length < 3) const _PartialCoverageNotice(),
          ],
        ],
      ),
    );
  }

  Future<void> _openArticle(Uri url) async {
    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir esta matéria.')),
      );
    }
  }
}

class _NewsNotice extends StatelessWidget {
  const _NewsNotice();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.public_rounded),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Acompanhe manchetes financeiras fornecidas pelo Marketaux. Ao abrir, você será direcionado ao site da fonte original.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onSelected});

  final MarketNewsCategory selected;
  final ValueChanged<MarketNewsCategory> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Categoria de notícias: ${selected.label}',
    child: Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final MarketNewsCategory category in MarketNewsCategory.values)
          ChoiceChip(
            key: ValueKey<String>('news-category-${category.storageValue}'),
            label: Text(category.label),
            selected: selected == category,
            onSelected: (bool value) {
              if (value) onSelected(category);
            },
          ),
      ],
    ),
  );
}

class _FeedStatus extends StatelessWidget {
  const _FeedStatus({required this.feed, required this.now});

  final MarketNewsFeed feed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool stale = feed.isStaleAt(now);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            feed.category.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Chip(
          avatar: Icon(
            stale ? Icons.history_rounded : Icons.cloud_done_outlined,
            size: 18,
          ),
          label: Text(stale ? 'Desatualizadas' : 'Atualizadas'),
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.category,
    required this.onOpen,
  });

  final MarketNewsArticle article;
  final MarketNewsCategory category;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ArticleThumbnail(article: article, category: category),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${article.source} · ${DateFormat('dd/MM/yyyy HH:mm').format(article.publishedAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.open_in_new_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _CategoryVisual extends StatelessWidget {
  const _CategoryVisual({required this.category, this.expanded = false});

  final MarketNewsCategory category;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (category) {
      MarketNewsCategory.market => Icons.candlestick_chart_rounded,
      MarketNewsCategory.economy => Icons.account_balance_rounded,
      MarketNewsCategory.international => Icons.public_rounded,
    };
    return Container(
      width: expanded ? double.infinity : 56,
      height: expanded ? double.infinity : 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _ArticleThumbnail extends StatelessWidget {
  const _ArticleThumbnail({required this.article, required this.category});

  final MarketNewsArticle article;
  final MarketNewsCategory category;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      key: ValueKey<String>('news-thumbnail-${article.id}'),
      width: 104,
      height: 88,
      child: article.imageUrl == null
          ? _CategoryVisual(category: category, expanded: true)
          : Image.network(
              article.imageUrl.toString(),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              frameBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    int? frame,
                    bool wasSynchronouslyLoaded,
                  ) => frame != null || wasSynchronouslyLoaded
                      ? child
                      : _CategoryVisual(category: category, expanded: true),
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) =>
                      _CategoryVisual(category: category, expanded: true),
            ),
    ),
  );
}

class _PartialCoverageNotice extends StatelessWidget {
  const _PartialCoverageNotice();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Text(
        'A fonte retornou menos de três matérias nesta categoria. A lista é exibida como cobertura parcial.',
      ),
    ),
  );
}

class _CategoryUnavailable extends StatelessWidget {
  const _CategoryUnavailable({required this.category, required this.onRetry});

  final MarketNewsCategory category;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _NewsStateCard(
    title: '${category.label} indisponível',
    message: 'Ainda não há um snapshot confirmado para esta categoria.',
    onRetry: onRetry,
  );
}

class _NewsUnavailable extends StatelessWidget {
  const _NewsUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _NewsStateCard(
        title: 'Notícias indisponíveis',
        message: 'Não foi possível confirmar as notícias no servidor agora.',
        onRetry: onRetry,
      ),
    ),
  );
}

class _NewsStateCard extends StatelessWidget {
  const _NewsStateCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const Icon(Icons.newspaper_outlined, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar estado'),
          ),
        ],
      ),
    ),
  );
}
