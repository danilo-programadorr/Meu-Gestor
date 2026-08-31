import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';

void main() {
  test('contrato remoto aceita somente mensagem segura e sem identidade', () {
    expect(
      AssistantRemoteRequest(message: 'Resumo confirmado').message,
      'Resumo confirmado',
    );
    expect(
      () => AssistantRemoteRequest(message: 'token=segredo'),
      throwsA(isA<AssistantFailure>()),
    );
  });

  test(
    'integração Flutter permanece permanentemente desligada e falha fechada',
    () async {
      expect(AssistantRemoteIntegrationPolicy.realCallsEnabled, isFalse);
      const DisabledAssistantRemoteRepository repository =
          DisabledAssistantRemoteRepository();
      await expectLater(
        repository.ask(message: 'Resumo confirmado'),
        throwsA(
          isA<AssistantFailure>().having(
            (AssistantFailure failure) => failure.kind,
            'kind',
            AssistantFailureKind.unavailable,
          ),
        ),
      );
    },
  );
}
