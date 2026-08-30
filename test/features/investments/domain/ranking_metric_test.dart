import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/ranking_metric.dart';

void main() {
  test('métricas do ranking não produzem dados quando a fonte não existe', () {
    expect(rankingMetricDefinitions, hasLength(9));
    expect(
      unavailableRankingReason(
        RankingMetric.grahamDifference,
        RankingAssetFilter.fiis,
      ),
      contains('não se aplica'),
    );
  });

  test('BDR permanece bloqueado até normalização compatível', () {
    for (final RankingMetricDefinition definition in rankingMetricDefinitions) {
      expect(
        unavailableRankingReason(definition.metric, RankingAssetFilter.bdrs),
        contains('normalização'),
      );
    }
  });
}
