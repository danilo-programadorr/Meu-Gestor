import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/firebase_assistant_remote_gateway.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';

void main() {
  test('gateway seleciona southamerica-east1 e nunca a região padrão', () {
    final String controllerSource = File(
      'lib/features/assistant/presentation/controllers/'
      'assistant_remote_conversation_controller.dart',
    ).readAsStringSync();

    expect(FirebaseAssistantRemoteGateway.callableRegion, 'southamerica-east1');
    expect(
      controllerSource,
      contains(
        'FirebaseFunctions.instanceFor(\n'
        '          region: FirebaseAssistantRemoteGateway.callableRegion,',
      ),
    );
    expect(controllerSource, isNot(contains('FirebaseFunctions.instance)')));
    expect(controllerSource, isNot(contains("region: 'us-central1'")));
  });

  test('flag desligada impede qualquer chamada de rede', () async {
    var calls = 0;
    final FirebaseAssistantRemoteGateway gateway =
        FirebaseAssistantRemoteGateway.withInvoker(
          invoker: (_) async {
            calls += 1;
            throw StateError('A rede não deveria ser chamada.');
          },
        );

    final AssistantRemoteResponse response = await gateway.ask(
      AssistantRemoteRequest(message: 'Explique o resumo confirmado.'),
    );

    expect(AssistantRemoteIntegrationPolicy.realCallsEnabled, isFalse);
    expect(calls, 0);
    expect(response, same(AssistantRemoteResponse.safeUnavailable));
    expect(response.safeMessage, contains('indisponível'));
  });

  test('payload contém somente o contrato e a mensagem sanitizada', () {
    final Map<String, Object?> payload =
        FirebaseAssistantRemoteGateway.payloadFor(
          AssistantRemoteRequest(message: '  Qual é o resumo?  '),
        );

    expect(payload, <String, Object?>{
      'contractVersion': 'assist-remote-v1',
      'message': 'Qual é o resumo?',
    });
    expect(payload.keys, hasLength(2));
    for (final String forbidden in <String>[
      'uid',
      'email',
      'context',
      'model',
      'token',
    ]) {
      expect(payload, isNot(contains(forbidden)));
    }
  });

  test('safe_unavailable tem resposta estrita e mensagem sem erro técnico', () {
    final AssistantRemoteResponse response =
        AssistantRemoteResponse.fromCallableData(<String, Object?>{
          'status': 'safe_unavailable',
          'contractVersion': 'assist-remote-v1',
        });

    expect(response, same(AssistantRemoteResponse.safeUnavailable));
    expect(response.safeMessage, isNot(contains('Firebase')));
    expect(response.safeMessage, isNot(contains('Exception')));
  });

  test('resposta fora do contrato é tratada como indisponibilidade segura', () {
    expect(
      () => AssistantRemoteResponse.fromCallableData(<String, Object?>{
        'status': 'safe_unavailable',
        'contractVersion': 'assist-remote-v1',
        'extra': true,
      }),
      throwsA(
        isA<AssistantFailure>().having(
          (AssistantFailure failure) => failure.kind,
          'kind',
          AssistantFailureKind.unavailable,
        ),
      ),
    );
  });
}
