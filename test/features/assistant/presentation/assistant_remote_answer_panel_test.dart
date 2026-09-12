// Intenção: mantém a resposta fundamentada automática legível e acessível no
// modo de texto, sem esconder fonte, período ou indisponibilidade segura.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_grounded_response.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_conversation_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/widgets/assistant_remote_answer_panel.dart';

void main() {
  testWidgets('mostra resposta, fonte e período sem ação adicional', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantRemoteAnswerPanel(
            state: AssistantRemoteConversationState(
              phase: AssistantRemoteConversationPhase.grounded,
              message: 'Resposta fundamentada pronta para leitura.',
              response: _response(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Resposta fundamentada'), findsOneWidget);
    expect(find.text('Resumo confirmado.'), findsOneWidget);
    expect(find.textContaining('Fonte: Contas e carteiras'), findsOneWidget);
    expect(find.textContaining('America/Sao_Paulo'), findsOneWidget);
    expect(find.text('Consultar resposta fundamentada'), findsNothing);
  });

  testWidgets('indisponibilidade segura não mostra resposta inventada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantRemoteAnswerPanel(
            state: AssistantRemoteConversationState(
              phase: AssistantRemoteConversationPhase.safeUnavailable,
              message:
                  'A resposta fundamentada está indisponível com segurança neste momento.',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('indisponível com segurança'), findsOneWidget);
    expect(find.text('Resumo confirmado.'), findsNothing);
  });
}

AssistantGroundedResponse _response() => AssistantGroundedResponse(
  status: AssistantGroundedResponseStatus.grounded,
  answer: 'Resumo confirmado.',
  assertions: <AssistantGroundedAssertion>[
    AssistantGroundedAssertion(
      statement: 'Há uma evidência confirmada.',
      evidence: AssistantResponseEvidenceReference(
        alias: 'ev_accounts_001',
        source: AssistantContextSource.accounts,
        period: AssistantCivilPeriod(
          startDate: '2026-09-01',
          endDateExclusive: '2026-09-02',
        ),
      ),
    ),
  ],
  missingData: const <String>[],
  disclaimer: 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
);
