import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';

void main() {
  // Intenção: preserva o contrato mínimo entre Flutter e callable sem campo
  // de identidade, contexto financeiro, modelo, custo ou credencial.
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

  test('resposta remota não aceita conteúdo, dados ou campos adicionais', () {
    expect(
      () => AssistantRemoteResponse.fromCallableData(<String, Object?>{
        'status': 'safe_unavailable',
        'contractVersion': AssistantRemoteRequest.contractVersion,
        'answer': 'conteúdo indevido',
      }),
      throwsA(isA<AssistantFailure>()),
    );
  });

  test('resposta fundamentada exige fonte e período civil estritos', () {
    final AssistantRemoteResponse response =
        AssistantRemoteResponse.fromCallableData(<String, Object?>{
          'schemaVersion': 1,
          'status': 'grounded',
          'answer': 'Resumo confirmado.',
          'assertions': <Object?>[
            <String, Object?>{
              'statement': 'Há uma evidência confirmada.',
              'evidence': <String, Object?>{
                'alias': 'ev_accounts_001',
                'source': 'accounts',
                'period': <String, Object?>{
                  'timeZone': 'America/Sao_Paulo',
                  'startDate': '2026-09-01',
                  'endDateExclusive': '2026-09-02',
                },
              },
            },
          ],
          'missingData': <Object?>[],
          'disclaimer':
              'Conteúdo informativo; nenhuma ação financeira foi realizada.',
        });

    expect(response.isGrounded, isTrue);
    expect(
      response.groundedResponse?.assertions.single.evidence.period.timeZone,
      'America/Sao_Paulo',
    );
    expect(
      () => AssistantRemoteResponse.fromCallableData(<String, Object?>{
        'schemaVersion': 1,
        'status': 'grounded',
        'answer': 'Resumo confirmado.',
        'assertions': <Object?>[],
        'missingData': <Object?>[],
        'disclaimer':
            'Conteúdo informativo; nenhuma ação financeira foi realizada.',
      }),
      throwsA(isA<AssistantFailure>()),
    );
  });

  test('resposta fundamentada bloqueia recomendação no texto visível', () {
    expect(
      () => AssistantRemoteResponse.fromCallableData(<String, Object?>{
        'schemaVersion': 1,
        'status': 'grounded',
        'answer': 'Compre este ativo.',
        'assertions': <Object?>[
          <String, Object?>{
            'statement': 'Há uma evidência confirmada.',
            'evidence': <String, Object?>{
              'alias': 'ev_accounts_001',
              'source': 'accounts',
              'period': <String, Object?>{
                'timeZone': 'America/Sao_Paulo',
                'startDate': '2026-09-01',
                'endDateExclusive': '2026-09-02',
              },
            },
          },
        ],
        'missingData': <Object?>[],
        'disclaimer': 'Conteúdo informativo.',
      }),
      throwsA(isA<AssistantFailure>()),
    );
  });
}
