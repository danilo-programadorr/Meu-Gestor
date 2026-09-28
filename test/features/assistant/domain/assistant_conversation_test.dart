import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';

void main() {
  test('modo de conversa usa pulso elétrico com partículas menores', () {
    expect(AssistantConversationVisualConfig.particleCount, 90);
    expect(AssistantConversationVisualConfig.pulseRingCount, 4);
    expect(
      AssistantConversationVisualConfig.pulseDuration,
      const Duration(milliseconds: 2400),
    );
    expect(
      AssistantConversationVisualConfig.maximumParticleRadius,
      lessThan(1.5),
    );
    expect(
      AssistantConversationVisualConfig.minimumParticleRadius,
      lessThan(AssistantConversationVisualConfig.maximumParticleRadius),
    );
  });

  test('mapeia somente perguntas determinísticas conhecidas', () {
    expect(
      AssistantConversationQuestionMatcher.match('Qual é meu saldo?'),
      AssistantGuidedQuestion.currentBalance,
    );
    expect(
      AssistantConversationQuestionMatcher.match('Quais contas preciso pagar?'),
      AssistantGuidedQuestion.commitmentStatus,
    );
    expect(
      AssistantConversationQuestionMatcher.match(
        'Como estão meus investimentos?',
      ),
      AssistantGuidedQuestion.investmentOverview,
    );
    expect(
      AssistantConversationQuestionMatcher.match('Me conte uma piada'),
      isNull,
    );
  });
}
