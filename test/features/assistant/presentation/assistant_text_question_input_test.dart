import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_conversation_page.dart';

void main() {
  testWidgets('texto mostra campo, envia por Enter e permite voltar à voz', (
    WidgetTester tester,
  ) async {
    int sends = 0;
    int returns = 0;
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantTextQuestionInput(
            controller: controller,
            onSend: () async => sends += 1,
            onUseVoice: () async => returns += 1,
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
    await tester.tap(find.text('Voltar ao modo de voz'));
    await tester.pump();
    expect(returns, 1);
  });
}
