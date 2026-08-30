import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_speech_recognizer.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_conversation.dart';

final Provider<AssistantSpeechRecognizer> assistantSpeechRecognizerProvider =
    Provider<AssistantSpeechRecognizer>(
      (Ref ref) => const MethodChannelAssistantSpeechRecognizer(),
    );

final NotifierProvider<
  AssistantConversationController,
  AssistantConversationState
>
assistantConversationControllerProvider =
    NotifierProvider.autoDispose<
      AssistantConversationController,
      AssistantConversationState
    >(AssistantConversationController.new);

final class AssistantConversationController
    extends Notifier<AssistantConversationState> {
  late AssistantSpeechRecognizer _recognizer;
  int _operation = 0;
  bool _disposed = false;
  StreamSubscription<double>? _rmsSubscription;

  @override
  AssistantConversationState build() {
    _recognizer = ref.watch(assistantSpeechRecognizerProvider);
    ref.onDispose(() {
      _disposed = true;
      _operation += 1;
      _rmsSubscription?.cancel();
      _recognizer.stop();
    });
    return const AssistantConversationState.initial();
  }

  Future<void> activate({required bool canUseVoice}) async {
    if (!canUseVoice) {
      _setPrivacyBlocked();
      return;
    }
    final int operation = ++_operation;
    await _rmsSubscription?.cancel();
    _rmsSubscription = null;
    state = state.copyWith(
      phase: AssistantConversationPhase.requestingPermission,
      message: 'Solicitando acesso ao microfone para reconhecer esta pergunta.',
      transcript: '',
      clearQuestion: true,
      voiceIntensity: 0,
    );
    try {
      if (!await _recognizer.isAvailable()) {
        if (operation == _operation && !_disposed) {
          state = state.copyWith(
            phase: AssistantConversationPhase.unavailable,
            message:
                'O reconhecimento de voz não está disponível neste aparelho. Use as perguntas por texto.',
          );
        }
        return;
      }
      if (operation == _operation && !_disposed) {
        state = state.copyWith(
          phase: AssistantConversationPhase.listening,
          message: 'Ouvindo. Toque em parar quando terminar.',
        );
        _listenToRms(operation);
      }
      final String transcript = await _recognizer.listen();
      if (operation != _operation || _disposed) return;
      state = state.copyWith(
        phase: AssistantConversationPhase.thinking,
        transcript: transcript,
        message: 'Verificando uma resposta determinística.',
      );
      final question = AssistantConversationQuestionMatcher.match(transcript);
      if (question == null) {
        state = state.copyWith(
          phase: AssistantConversationPhase.ready,
          message:
              'Ainda não tenho uma resposta determinística para essa pergunta. Use uma pergunta disponível por texto.',
          clearQuestion: true,
        );
      } else {
        state = state.copyWith(
          phase: AssistantConversationPhase.thinking,
          message: 'Pergunta reconhecida. Preparando resposta confirmada.',
          question: question,
        );
      }
    } on AssistantSpeechException catch (error) {
      if (operation == _operation && !_disposed) _setSpeechFailure(error.code);
    } on Object {
      if (operation == _operation && !_disposed) _setSpeechFailure('unknown');
    }
  }

  Future<bool> hasMicrophonePermission() =>
      _recognizer.hasMicrophonePermission();

  void _listenToRms(int operation) {
    _rmsSubscription = _recognizer.rmsLevels.listen((double rms) {
      if (operation != _operation || _disposed) return;
      final double target = ((rms + 2) / 14).clamp(0, 1).toDouble();
      final double smoothed = state.voiceIntensity * .72 + target * .28;
      state = state.copyWith(voiceIntensity: smoothed);
    });
  }

  void speaking() {
    if (!_disposed) {
      state = state.copyWith(
        phase: AssistantConversationPhase.speaking,
        message: 'Respondendo em voz. A resposta escrita continua visível.',
      );
    }
  }

  void noConfirmedAnswer() {
    if (!_disposed) {
      state = state.copyWith(
        phase: AssistantConversationPhase.ready,
        message:
            'Não há dados confirmados suficientes para responder por voz. A limitação foi mantida em texto.',
      );
    }
  }

  Future<void> stopAndClear({bool preserveTranscript = false}) async {
    _operation += 1;
    await _rmsSubscription?.cancel();
    _rmsSubscription = null;
    try {
      await _recognizer.stop();
    } on Object {
      // O encerramento nativo não altera a garantia de descarte local.
    }
    if (!_disposed) {
      state = AssistantConversationState.initial().copyWith(
        transcript: preserveTranscript ? state.transcript : '',
      );
    }
  }

  Future<void> interrupt() => stopAndClear();

  void _setPrivacyBlocked() {
    state = state.copyWith(
      phase: AssistantConversationPhase.ready,
      transcript: '',
      message:
          'O modo de voz foi interrompido porque a privacidade financeira está ativa. Use texto ou mostre os dados para continuar.',
      clearQuestion: true,
    );
  }

  void _setSpeechFailure(String code) {
    final bool denied = code == 'permission_denied';
    state = state.copyWith(
      phase: denied
          ? AssistantConversationPhase.permissionDenied
          : AssistantConversationPhase.failed,
      message: denied
          ? 'O microfone não foi autorizado. Você ainda pode usar as perguntas por texto.'
          : 'Não foi possível reconhecer a pergunta. Tente novamente ou use texto.',
      clearQuestion: true,
    );
  }
}
