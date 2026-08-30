import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/ranking_metric.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  RankingAssetFilter _filter = RankingAssetFilter.shares;

  @override
  Widget build(BuildContext context) => SafeBackScope(
    fallbackLocation: AppRoutes.investments,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.investments),
        title: const Text('Rankings'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Text(
                'Indicadores por fundamento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Compare somente métricas objetivas quando houver fonte automática validada.',
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterBar(value: _filter, onChanged: _changeFilter),
              const SizedBox(height: AppSpacing.md),
              _MetadataCard(filter: _filter),
              const SizedBox(height: AppSpacing.md),
              _MetricGrid(filter: _filter, wide: constraints.maxWidth >= 620),
              const SizedBox(height: AppSpacing.md),
              const _Disclaimer(),
            ],
          ),
        ),
      ),
    ),
  );

  void _changeFilter(RankingAssetFilter value) =>
      setState(() => _filter = value);
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final RankingAssetFilter value;
  final ValueChanged<RankingAssetFilter> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Filtro de classe de ativo',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<RankingAssetFilter>(
        segments: <ButtonSegment<RankingAssetFilter>>[
          for (final RankingAssetFilter filter in RankingAssetFilter.values)
            ButtonSegment<RankingAssetFilter>(
              value: filter,
              label: Text(filter.label),
            ),
        ],
        selected: <RankingAssetFilter>{value},
        onSelectionChanged: (Set<RankingAssetFilter> values) =>
            onChanged(values.single),
      ),
    ),
  );
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.filter});

  final RankingAssetFilter filter;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Semantics(
        label:
            'Classe ${filter.label}. Fonte indisponível. Data indisponível. Moeda indisponível. Atraso indisponível.',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Dados de mercado indisponíveis'),
            SizedBox(height: AppSpacing.xs),
            Text('Fonte: aguardando integração validada'),
            Text('Data: indisponível • Moeda: indisponível'),
            Text('Atraso: indisponível'),
          ],
        ),
      ),
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.filter, required this.wide});

  final RankingAssetFilter filter;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rankingMetricDefinitions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 2 : 1,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: largeText ? 260 : 208,
      ),
      itemBuilder: (BuildContext context, int index) => _MetricCard(
        definition: rankingMetricDefinitions[index],
        filter: filter,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.definition, required this.filter});

  final RankingMetricDefinition definition;
  final RankingAssetFilter filter;

  @override
  Widget build(BuildContext context) {
    final String reason = unavailableRankingReason(definition.metric, filter);
    return Card(
      child: Semantics(
        label: '${definition.title}. Indisponível. $reason',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                definition.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                definition.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Indisponível',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Text(
        'Rankings e indicadores são apenas informativos e não constituem recomendação de compra ou venda.',
      ),
    ),
  );
}
