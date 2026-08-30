import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';

void main() {
  test('modo de conversa usa trinta partículas determinísticas', () {
    expect(AssistantConversationVisualConfig.particleCount, 30);
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
