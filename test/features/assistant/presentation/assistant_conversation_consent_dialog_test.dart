import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_conversation_page.dart';

void main() {
  testWidgets('popup oferece uma decisão clara e não navega ao recusar', (
    WidgetTester tester,
  ) async {
    bool declined = false;
    await tester.pumpWidget(
      _dialog(
        state: const AssistantConversationConsentState(
          phase: AssistantConversationConsentPhase.required,
        ),
        onDecline: () => declined = true,
      ),
    );

    expect(find.text('Ativar Assistente Financeiro'), findsOneWidget);
    expect(find.text('Ativar e continuar'), findsOneWidget);
    await tester.tap(find.text('Agora não'));

    expect(declined, isTrue);
    expect(find.text('Ativar Assistente Financeiro'), findsOneWidget);
  });

  testWidgets('popup mostra erro de gravação e permite nova tentativa', (
    WidgetTester tester,
  ) async {
    int activations = 0;
    await tester.pumpWidget(
      _dialog(
        state: const AssistantConversationConsentState(
          phase: AssistantConversationConsentPhase.failed,
          message: 'Não foi possível ativar o Assistente Financeiro.',
        ),
        onActivate: () async => activations += 1,
      ),
    );

    expect(
      find.text('Não foi possível ativar o Assistente Financeiro.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-consent-activate-action')),
    );
    await tester.pump();

    expect(activations, 1);
  });
}

Widget _dialog({
  required AssistantConversationConsentState state,
  VoidCallback? onDecline,
  Future<void> Function()? onActivate,
}) => MaterialApp(
  home: Scaffold(
    body: AssistantConversationConsentDialog(
      state: state,
      onActivate: onActivate ?? () async {},
      onDecline: onDecline ?? () {},
    ),
  ),
);
