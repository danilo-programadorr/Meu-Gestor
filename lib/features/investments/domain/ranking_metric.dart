enum RankingAssetFilter { shares, fiis, stocks, bdrs }

enum RankingMetric {
  marketCapitalization,
  dividendYield,
  netMargin,
  revenue,
  profit,
  grahamDifference,
  fiiBookReference,
  bazinCeiling,
  longTermIndicators,
}

extension RankingAssetFilterText on RankingAssetFilter {
  String get label => switch (this) {
    RankingAssetFilter.shares => 'Ações',
    RankingAssetFilter.fiis => 'FIIs',
    RankingAssetFilter.stocks => 'Stocks',
    RankingAssetFilter.bdrs => 'BDRs',
  };
}

final class RankingMetricDefinition {
  const RankingMetricDefinition({
    required this.metric,
    required this.title,
    required this.description,
  });

  final RankingMetric metric;
  final String title;
  final String description;
}

const List<RankingMetricDefinition>
rankingMetricDefinitions = <RankingMetricDefinition>[
  RankingMetricDefinition(
    metric: RankingMetric.marketCapitalization,
    title: 'Capitalização',
    description: 'Valor de mercado informado pela fonte validada.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.dividendYield,
    title: 'Dividend yield',
    description: 'Indicador histórico, sem promessa de distribuição futura.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.netMargin,
    title: 'Margem líquida',
    description: 'Relação entre lucro líquido e receita no período informado.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.revenue,
    title: 'Maiores receitas',
    description: 'Receita reportada no período da fonte.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.profit,
    title: 'Maiores lucros',
    description: 'Lucro reportado no período da fonte.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.grahamDifference,
    title: 'Diferença versus Graham',
    description: 'Comparação teórica, não recomendação de compra ou venda.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.fiiBookReference,
    title: 'Referência patrimonial FII',
    description: 'P/VP e deságio/ágio frente ao valor patrimonial por cota.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.bazinCeiling,
    title: 'Preço-teto Bazin',
    description: 'Referência matemática baseada em proventos validados.',
  ),
  RankingMetricDefinition(
    metric: RankingMetric.longTermIndicators,
    title: 'Indicadores de longo prazo',
    description: 'Séries históricas somente quando a fonte cobrir o período.',
  ),
];

String unavailableRankingReason(
  RankingMetric metric,
  RankingAssetFilter filter,
) {
  if (filter == RankingAssetFilter.bdrs) {
    return 'BDRs aguardam normalização de moeda, recibo e ativo subjacente.';
  }
  if (filter == RankingAssetFilter.fiis &&
      metric == RankingMetric.grahamDifference) {
    return 'Número de Graham não se aplica a FIIs; use a referência patrimonial.';
  }
  if (filter != RankingAssetFilter.fiis &&
      metric == RankingMetric.fiiBookReference) {
    return 'Referência patrimonial disponível somente para FIIs.';
  }
  return 'Aguardando dados fundamentais automáticos validados.';
}
