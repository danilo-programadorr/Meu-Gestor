import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_conversation_page.dart';

void main() {
  testWidgets('apresentação explica limites e oferece uma decisão clara', (
    WidgetTester tester,
  ) async {
    int continuations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantIntroductionDialog(
            onContinue: () async => continuations += 1,
          ),
        ),
      ),
    );

    expect(find.text('Prazer, eu sou a Luma'), findsOneWidget);
    expect(find.textContaining('Não faço movimentações'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pump();
    expect(continuations, 1);
  });

  test('modo voz não possui fallback para TTS local do Android', () {
    final String source = File(
      'lib/features/assistant/presentation/pages/assistant_conversation_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_voice.speak(')));
    expect(source, isNot(contains('Android pode usar a voz local')));
    expect(source, contains('_voice.playAudio('));
  });
}
