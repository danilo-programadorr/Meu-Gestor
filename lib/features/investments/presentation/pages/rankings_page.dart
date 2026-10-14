import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Widget build(BuildContext context) {
    final List<RankingMetricDefinition> metrics = rankingMetricsFor(_filter);
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: const Text('Rankings'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.compactPageHorizontal,
              AppSpacing.md,
              AppSpacing.compactPageHorizontal,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  'Explore indicadores',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Conheça as métricas previstas para cada classe. Um ranking só será publicado quando fonte, período e cobertura puderem ser validados.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _FilterBar(value: _filter, onChanged: _changeFilter),
              const SizedBox(height: AppSpacing.md),
              _PreparationCard(filter: _filter),
              const SizedBox(height: AppSpacing.md),
              const _HelpfulActions(),
              const SizedBox(height: AppSpacing.lg),
              if (metrics.isEmpty)
                const _BdrPendingCard()
              else ...<Widget>[
                Text(
                  'Indicadores previstos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${metrics.length} métricas compatíveis com ${_filter.label}. Nenhum valor ou posição é estimado.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetricCatalog(definitions: metrics),
              ],
              const SizedBox(height: AppSpacing.md),
              const _Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  void _changeFilter(RankingAssetFilter value) =>
      setState(() => _filter = value);
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final RankingAssetFilter value;
  final ValueChanged<RankingAssetFilter> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Classe de ativo selecionada: ${value.label}',
    child: Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final RankingAssetFilter filter in RankingAssetFilter.values)
          ChoiceChip(
            key: ValueKey<String>('ranking-filter-${filter.name}'),
            label: Text(filter.label),
            selected: filter == value,
            onSelected: (bool selected) {
              if (selected) onChanged(filter);
            },
          ),
      ],
    ),
  );
}

// O estado único evita repetir nove falhas visuais e deixa explícito que a
// indisponibilidade é estrutural, não uma falha temporária da pessoa usuária.
class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.filter});

  final RankingAssetFilter filter;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label:
          'Rankings de ${filter.label} em preparação. Fonte fundamentalista não integrada. Nenhuma atualização disponível.',
      child: Card(
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.hourglass_top_rounded, color: colors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Rankings de ${filter.label} em preparação',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        const Text(
                          'Ainda não existe uma fonte fundamentalista integrada e validada para ordenar ativos com segurança.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              const _StatusLine(
                label: 'Fonte fundamentalista',
                value: 'Não integrada',
              ),
              const SizedBox(height: AppSpacing.xs),
              const _StatusLine(
                label: 'Última atualização',
                value: 'Ainda não disponível',
              ),
              const SizedBox(height: AppSpacing.xs),
              const _StatusLine(
                label: 'Lista ordenada',
                value: 'Não publicada',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(
        Icons.info_outline_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(child: Text('$label: $value')),
    ],
  );
}

class _MetricCatalog extends StatelessWidget {
  const _MetricCatalog({required this.definitions});

  final List<RankingMetricDefinition> definitions;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: <Widget>[
        for (int index = 0; index < definitions.length; index++) ...<Widget>[
          _MetricEntry(definition: definitions[index]),
          if (index < definitions.length - 1)
            const Divider(height: 1, indent: 64),
        ],
      ],
    ),
  );
}

class _MetricEntry extends StatelessWidget {
  const _MetricEntry({required this.definition});

  final RankingMetricDefinition definition;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${definition.title}. ${definition.description}',
    child: ListTile(
      leading: CircleAvatar(child: Icon(_metricIcon(definition.metric))),
      title: Text(definition.title),
      subtitle: Text(definition.description),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    ),
  );
}

IconData _metricIcon(RankingMetric metric) => switch (metric) {
  RankingMetric.marketCapitalization => Icons.account_balance_outlined,
  RankingMetric.dividendYield => Icons.payments_outlined,
  RankingMetric.netMargin => Icons.percent_rounded,
  RankingMetric.revenue => Icons.trending_up_rounded,
  RankingMetric.profit => Icons.savings_outlined,
  RankingMetric.grahamDifference => Icons.functions_rounded,
  RankingMetric.fiiBookReference => Icons.apartment_rounded,
  RankingMetric.bazinCeiling => Icons.price_check_outlined,
  RankingMetric.longTermIndicators => Icons.timeline_rounded,
};

class _BdrPendingCard extends StatelessWidget {
  const _BdrPendingCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.currency_exchange_rounded),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BDRs precisam de normalização adicional',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Moeda, relação do recibo e ativo subjacente precisam ser compatíveis antes que qualquer indicador seja comparado.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HelpfulActions extends StatelessWidget {
  const _HelpfulActions();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Enquanto isso', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Use ferramentas que já possuem regras e fontes claramente identificadas.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton.icon(
                key: const ValueKey<String>('ranking-open-tools'),
                onPressed: () => context.push(AppRoutes.investmentTools),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Abrir calculadoras'),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('ranking-open-quotes'),
                onPressed: () => context.push(AppRoutes.investmentQuotes),
                icon: const Icon(Icons.show_chart_rounded),
                label: const Text('Ver cotações'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        'Rankings e indicadores são informativos e não constituem recomendação financeira.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'Rankings e indicadores são apenas informativos e não constituem recomendação de compra ou venda.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
