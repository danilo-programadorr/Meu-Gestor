// Intenção: protege a ponte Flutter contra chamadas automáticas, ausência de
// consentimento, privacidade, resposta malformada e retorno remoto tardio.
import 'dart:async';

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
    'consentimento ausente e privacidade ativa não chegam ao gateway',
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
}

Future<void> _request(
  ProviderContainer container, {
  bool consent = true,
  bool valuesVisible = true,
}) => container
    .read(assistantRemoteConversationControllerProvider.notifier)
    .requestGroundedAnswer(
      message: 'Explique o resumo confirmado.',
      aiConsentEnabled: consent,
      financialValuesVisible: valuesVisible,
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
  _FakeGateway({this.result, this.failure, this.future});

  final AssistantRemoteResponse? result;
  final AssistantFailure? failure;
  final Future<AssistantRemoteResponse>? future;
  int calls = 0;

  @override
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request) {
    calls += 1;
    if (failure case final AssistantFailure error) {
      return Future<AssistantRemoteResponse>.error(error);
    }
    if (future case final Future<AssistantRemoteResponse> pending) {
      return pending;
    }
    return Future<AssistantRemoteResponse>.value(
      result ?? AssistantRemoteResponse.safeUnavailable,
    );
  }
}
