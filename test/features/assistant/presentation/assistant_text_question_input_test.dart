import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_conversation_page.dart';

void main() {
  testWidgets(
    'texto mostra somente campo e envio, sem card de transcrição ou retorno à voz',
    (WidgetTester tester) async {
      int sends = 0;
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssistantTextQuestionInput(
              controller: controller,
              onSend: () async => sends += 1,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('assistant-text-question-field')),
        'Qual é meu saldo?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(sends, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('assistant-text-send-action')),
      );
      await tester.pump();
      expect(sends, 2);
      expect(find.text('Transcrição desta sessão'), findsNothing);
      expect(find.text('Voltar ao modo de voz'), findsNothing);
      expect(find.text('Pergunta por texto'), findsNothing);
    },
  );
}
