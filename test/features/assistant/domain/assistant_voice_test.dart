import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_voice.dart';

void main() {
  test('formata somente a resposta determinística visível em pt-BR', () {
    final String speech = AssistantSpeechFormatter.format(
      const AssistantDeterministicSummary(
        title: 'Resumo do mês',
        observation: 'Receitas superam despesas.',
        periodLabel: 'Agosto de 2026',
        metrics: <AssistantSummaryMetric>[
          AssistantSummaryMetric.money('Resultado', 123456),
          AssistantSummaryMetric.count('Lançamentos', 4),
        ],
        sources: <AssistantContextSource>{AssistantContextSource.transactions},
        isAvailable: true,
      ),
    );

    expect(speech, contains('R\$ 1.234,56'));
    expect(speech, contains('Lançamentos: 4'));
    expect(speech, contains('somente leitura'));
    expect(speech, isNot(contains('UID')));
  });
}
