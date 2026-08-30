import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_speech_recognizer.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_controller.dart';

void main() {
  test('reconhece pergunta permitida e não guarda áudio', () async {
    final _FakeSpeech speech = _FakeSpeech(transcript: 'Qual é meu saldo?');
    final ProviderContainer container = _container(speech);
    addTearDown(container.dispose);

    await container
        .read(assistantConversationControllerProvider.notifier)
        .activate(canUseVoice: true);

    final AssistantConversationState state = container.read(
      assistantConversationControllerProvider,
    );
    expect(state.transcript, 'Qual é meu saldo?');
    expect(state.question, AssistantGuidedQuestion.currentBalance);
    expect(speech.stopCalls, 0);
  });

  test(
    'nega privacidade, permissão e indisponibilidade sem resposta inventada',
    () async {
      final _FakeSpeech denied = _FakeSpeech(error: 'permission_denied');
      final ProviderContainer container = _container(denied);
      addTearDown(container.dispose);
      final AssistantConversationController controller = container.read(
        assistantConversationControllerProvider.notifier,
      );

      await controller.activate(canUseVoice: false);
      expect(
        container.read(assistantConversationControllerProvider).transcript,
        isEmpty,
      );
      await controller.activate(canUseVoice: true);
      expect(
        container.read(assistantConversationControllerProvider).phase,
        AssistantConversationPhase.permissionDenied,
      );
    },
  );

  test('saída limpa transcrição e interrompe o reconhecedor', () async {
    final _FakeSpeech speech = _FakeSpeech(transcript: 'Qual é meu saldo?');
    final ProviderContainer container = _container(speech);
    addTearDown(container.dispose);
    final AssistantConversationController controller = container.read(
      assistantConversationControllerProvider.notifier,
    );
    await controller.activate(canUseVoice: true);
    await controller.interrupt();
    expect(
      container.read(assistantConversationControllerProvider).transcript,
      isEmpty,
    );
    expect(speech.stopCalls, 1);
  });

  test('normaliza RMS efêmero sem reter áudio', () async {
    final Completer<void> subscribed = Completer<void>();
    final StreamController<double> rms = StreamController<double>.broadcast(
      sync: true,
      onListen: subscribed.complete,
    );
    final _FakeSpeech speech = _FakeSpeech(
      transcript: 'Qual é meu saldo?',
      rms: rms.stream,
      listenDelay: const Duration(milliseconds: 20),
    );
    final ProviderContainer container = _container(speech);
    addTearDown(container.dispose);

    final Future<void> activation = container
        .read(assistantConversationControllerProvider.notifier)
        .activate(canUseVoice: true);
    await subscribed.future;
    rms.add(8);
    expect(
      container.read(assistantConversationControllerProvider).voiceIntensity,
      greaterThan(0),
    );
    await activation;
    await container
        .read(assistantConversationControllerProvider.notifier)
        .interrupt();
    unawaited(rms.close());
  });

  test('expõe a permissão nativa sem solicitar escuta', () async {
    final _FakeSpeech speech = _FakeSpeech(
      transcript: 'Qual é meu saldo?',
      hasPermission: true,
    );
    final ProviderContainer container = _container(speech);
    addTearDown(container.dispose);

    expect(
      await container
          .read(assistantConversationControllerProvider.notifier)
          .hasMicrophonePermission(),
      isTrue,
    );
    expect(speech.listenCalls, 0);
  });
}

ProviderContainer _container(_FakeSpeech speech) => ProviderContainer(
  overrides: [assistantSpeechRecognizerProvider.overrideWithValue(speech)],
);

final class _FakeSpeech implements AssistantSpeechRecognizer {
  _FakeSpeech({
    this.transcript,
    this.error,
    this.hasPermission = false,
    Stream<double>? rms,
    this.listenDelay = Duration.zero,
  }) : _rms = rms ?? const Stream<double>.empty();
  final String? transcript;
  final String? error;
  final bool hasPermission;
  final Stream<double> _rms;
  final Duration listenDelay;
  int stopCalls = 0;
  int listenCalls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasMicrophonePermission() async => hasPermission;

  @override
  Stream<double> get rmsLevels => _rms;

  @override
  Future<String> listen() async {
    listenCalls += 1;
    if (error case final String code) throw AssistantSpeechException(code);
    if (listenDelay > Duration.zero) await Future<void>.delayed(listenDelay);
    return transcript!;
  }

  @override
  Future<void> stop() async => stopCalls += 1;
}
