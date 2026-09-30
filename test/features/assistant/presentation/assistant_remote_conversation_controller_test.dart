// Intenção: protege o envio automático contra ausência de consentimento,
// privacidade, resposta malformada e retorno remoto tardio.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_conversation_controller.dart';

void main() {
  test(
    'flag desligada bloqueia a consulta antes de chamar o gateway',
    () async {
      final _FakeGateway gateway = _FakeGateway();
      final ProviderContainer container = _container(gateway: gateway);
      addTearDown(container.dispose);

      await _request(container);

      expect(gateway.calls, 0);
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.safeUnavailable,
      );
    },
  );

  test(
    'consentimentos ausentes e privacidade ativa não chegam ao gateway',
    () async {
      final _FakeGateway gateway = _FakeGateway();
      final ProviderContainer container = _container(
        gateway: gateway,
        enabled: true,
      );
      addTearDown(container.dispose);

      await _request(container, consent: false);
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.consentRequired,
      );
      await _request(container, remoteConsent: false);
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.consentRequired,
      );
      await _request(container, valuesVisible: false);
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.privacyBlocked,
      );
      expect(gateway.calls, 0);
    },
  );

  test(
    'resposta válida mostra somente evidência, fonte e período civil',
    () async {
      final _FakeGateway gateway = _FakeGateway(
        result: AssistantRemoteResponse.fromCallableData(_groundedCallable()),
      );
      final ProviderContainer container = _container(
        gateway: gateway,
        enabled: true,
      );
      addTearDown(container.dispose);

      await _request(container);

      final AssistantRemoteConversationState state = container.read(
        assistantRemoteConversationControllerProvider,
      );
      expect(gateway.calls, 1);
      expect(state.phase, AssistantRemoteConversationPhase.grounded);
      expect(
        state.response?.assertions.single.evidence.alias,
        'ev_accounts_001',
      );
      expect(
        state.response?.assertions.single.evidence.period.timeZone,
        'America/Sao_Paulo',
      );
    },
  );

  test('modo voz solicita e preserva somente o WAV efêmero', () async {
    final Uint8List wav = Uint8List(524)
      ..setRange(0, 4, ascii.encode('RIFF'))
      ..setRange(8, 12, ascii.encode('WAVE'));
    final _FakeGateway gateway = _FakeGateway(
      result: AssistantRemoteResponse.fromCallableData(<String, Object?>{
        ..._groundedCallable(),
        'audio': <String, Object?>{
          'mimeType': 'audio/wav',
          'dataBase64': base64Encode(wav),
        },
      }),
    );
    final ProviderContainer container = _container(
      gateway: gateway,
      enabled: true,
    );
    addTearDown(container.dispose);

    await _request(container, voiceOnly: true);

    expect(
      gateway.requests.single.responseMode,
      AssistantRemoteResponseMode.voice,
    );
    expect(
      container.read(assistantRemoteConversationControllerProvider).audio?.bytes,
      orderedEquals(wav),
    );
  });

  test('indisponibilidade e falha de contrato não inventam resposta', () async {
    final _FakeGateway gateway = _FakeGateway(
      failure: const AssistantFailure(AssistantFailureKind.unavailable),
    );
    final ProviderContainer container = _container(
      gateway: gateway,
      enabled: true,
    );
    addTearDown(container.dispose);

    await _request(container);

    final AssistantRemoteConversationState state = container.read(
      assistantRemoteConversationControllerProvider,
    );
    expect(state.phase, AssistantRemoteConversationPhase.safeUnavailable);
    expect(state.response, isNull);
  });

  test(
    'esclarecimento preserva um turno e a resposta seguinte o consome',
    () async {
      final _FakeGateway gateway = _FakeGateway(
        results: <AssistantRemoteResponse>[
          AssistantRemoteResponse.fromCallableData(<String, Object?>{
            'status': 'clarification_required',
            'contractVersion': 'assist-remote-v1',
            'intent': 'financial_overview',
            'clarificationCode': 'period_required',
            'question': 'Qual período você quer analisar?',
          }),
          AssistantRemoteResponse.fromCallableData(_groundedCallable()),
        ],
      );
      final ProviderContainer container = _container(
        gateway: gateway,
        enabled: true,
      );
      addTearDown(container.dispose);

      await _request(container, message: 'Prepare um relatório.');
      final AssistantRemoteConversationState clarification = container.read(
        assistantRemoteConversationControllerProvider,
      );
      expect(
        clarification.phase,
        AssistantRemoteConversationPhase.clarificationRequired,
      );
      expect(clarification.message, 'Qual período você quer analisar?');

      await _request(container, message: 'Deste mês.');
      expect(
        gateway.requests[1].continuation?.previousMessage,
        'Prepare um relatório.',
      );
      expect(
        gateway.requests[1].continuation?.clarificationCode,
        'period_required',
      );
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.grounded,
      );
    },
  );

  test(
    'resposta fundamentada mantém somente a última pergunta para continuação',
    () async {
      final _FakeGateway gateway = _FakeGateway(
        results: <AssistantRemoteResponse>[
          AssistantRemoteResponse.fromCallableData(_groundedCallable()),
          AssistantRemoteResponse.fromCallableData(_groundedCallable()),
        ],
      );
      final ProviderContainer container = _container(
        gateway: gateway,
        enabled: true,
      );
      addTearDown(container.dispose);

      await _request(container, message: 'Como estão meus gastos?');
      await _request(container, message: 'E no mês passado?');

      final AssistantRemoteContinuation? continuation =
          gateway.requests[1].continuation;
      expect(continuation?.previousMessage, 'Como estão meus gastos?');
      expect(continuation?.intent, 'unknown');
      expect(continuation?.clarificationCode, 'intent_ambiguous');
    },
  );

  test('privacidade apaga continuação e impede retorno tardio', () async {
    final _FakeGateway gateway = _FakeGateway(
      result: AssistantRemoteResponse.fromCallableData(<String, Object?>{
        'status': 'clarification_required',
        'contractVersion': 'assist-remote-v1',
        'intent': 'financial_overview',
        'clarificationCode': 'period_required',
        'question': 'Qual período você quer analisar?',
      }),
    );
    final ProviderContainer container = _container(
      gateway: gateway,
      enabled: true,
    );
    addTearDown(container.dispose);
    await _request(container, message: 'Prepare um relatório.');

    container
        .read(assistantRemoteConversationControllerProvider.notifier)
        .blockForFinancialPrivacy();
    await _request(container, message: 'Deste mês.', valuesVisible: false);

    expect(gateway.calls, 1);
    expect(
      container.read(assistantRemoteConversationControllerProvider).phase,
      AssistantRemoteConversationPhase.privacyBlocked,
    );
  });

  test('resposta tardia não restaura conteúdo depois da privacidade', () async {
    final Completer<AssistantRemoteResponse> result =
        Completer<AssistantRemoteResponse>();
    final _FakeGateway gateway = _FakeGateway(future: result.future);
    final ProviderContainer container = _container(
      gateway: gateway,
      enabled: true,
    );
    addTearDown(container.dispose);

    final Future<void> pending = _request(container);
    await Future<void>.delayed(Duration.zero);
    container
        .read(assistantRemoteConversationControllerProvider.notifier)
        .blockForFinancialPrivacy();
    result.complete(
      AssistantRemoteResponse.fromCallableData(_groundedCallable()),
    );
    await pending;

    expect(
      container.read(assistantRemoteConversationControllerProvider).phase,
      AssistantRemoteConversationPhase.privacyBlocked,
    );
  });

  test(
    'resposta antiga não substitui nova pergunta após descarte de sessão',
    () async {
      final Completer<AssistantRemoteResponse> first =
          Completer<AssistantRemoteResponse>();
      final Completer<AssistantRemoteResponse> second =
          Completer<AssistantRemoteResponse>();
      final _QueuedGateway gateway = _QueuedGateway(
        <Future<AssistantRemoteResponse>>[first.future, second.future],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          assistantRemoteGatewayProvider.overrideWithValue(gateway),
          assistantRemoteCallPolicyProvider.overrideWithValue(
            const _FakePolicy(true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AssistantRemoteConversationState>
      subscription = container.listen(
        assistantRemoteConversationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final AssistantRemoteConversationController controller = container.read(
        assistantRemoteConversationControllerProvider.notifier,
      );

      final Future<void> oldRequest = _request(container);
      await Future<void>.delayed(Duration.zero);
      controller.discard();
      final Future<void> currentRequest = _request(container);
      await Future<void>.delayed(Duration.zero);

      first.complete(
        AssistantRemoteResponse.fromCallableData(_groundedCallable()),
      );
      await oldRequest;
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.preparing,
      );

      second.complete(AssistantRemoteResponse.safeUnavailable);
      await currentRequest;
      expect(
        container.read(assistantRemoteConversationControllerProvider).phase,
        AssistantRemoteConversationPhase.safeUnavailable,
      );
    },
  );
}

Future<void> _request(
  ProviderContainer container, {
  String message = 'Explique o resumo confirmado.',
  bool consent = true,
  bool remoteConsent = true,
  bool valuesVisible = true,
  bool voiceOnly = false,
}) => container
    .read(assistantRemoteConversationControllerProvider.notifier)
    .requestGroundedAnswer(
      message: message,
      aiConsentEnabled: consent,
      remoteContextConsentAllowed: remoteConsent,
      financialValuesVisible: valuesVisible,
      voiceOnly: voiceOnly,
    );

ProviderContainer _container({
  required _FakeGateway gateway,
  bool enabled = false,
}) => ProviderContainer(
  overrides: [
    assistantRemoteGatewayProvider.overrideWithValue(gateway),
    assistantRemoteCallPolicyProvider.overrideWithValue(_FakePolicy(enabled)),
  ],
);

Map<String, Object?> _groundedCallable() => <String, Object?>{
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
  'disclaimer': 'Conteúdo informativo; nenhuma ação financeira foi realizada.',
};

final class _FakePolicy implements AssistantRemoteCallPolicy {
  const _FakePolicy(this.callsEnabled);

  @override
  final bool callsEnabled;
}

final class _FakeGateway implements AssistantRemoteGateway {
  _FakeGateway({this.result, this.results, this.failure, this.future});

  final AssistantRemoteResponse? result;
  final List<AssistantRemoteResponse>? results;
  final AssistantFailure? failure;
  final Future<AssistantRemoteResponse>? future;
  int calls = 0;
  final List<AssistantRemoteRequest> requests = <AssistantRemoteRequest>[];

  @override
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request) {
    requests.add(request);
    calls += 1;
    if (failure case final AssistantFailure error) {
      return Future<AssistantRemoteResponse>.error(error);
    }
    if (future case final Future<AssistantRemoteResponse> pending) {
      return pending;
    }
    final List<AssistantRemoteResponse>? queued = results;
    return Future<AssistantRemoteResponse>.value(
      queued == null
          ? result ?? AssistantRemoteResponse.safeUnavailable
          : queued[calls - 1],
    );
  }
}

final class _QueuedGateway implements AssistantRemoteGateway {
  _QueuedGateway(this.responses);

  final List<Future<AssistantRemoteResponse>> responses;
  int calls = 0;

  @override
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request) {
    final Future<AssistantRemoteResponse> response = responses[calls];
    calls += 1;
    return response;
  }
}
