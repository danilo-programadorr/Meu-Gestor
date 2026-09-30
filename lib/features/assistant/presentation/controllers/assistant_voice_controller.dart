import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_audio_player.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_tts_engine.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_voice.dart';

final Provider<AssistantTtsEngine> assistantTtsEngineProvider =
    Provider<AssistantTtsEngine>((Ref ref) => FlutterAssistantTtsEngine());

final NotifierProvider<AssistantVoiceController, AssistantVoiceState>
assistantVoiceControllerProvider =
    NotifierProvider.autoDispose<AssistantVoiceController, AssistantVoiceState>(
      AssistantVoiceController.new,
    );

final Provider<AssistantAudioPlayer> assistantAudioPlayerProvider =
    Provider<AssistantAudioPlayer>(
      (Ref ref) => const MethodChannelAssistantAudioPlayer(),
    );

final class AssistantVoiceController extends Notifier<AssistantVoiceState> {
  late AssistantTtsEngine _engine;
  late AssistantAudioPlayer _audioPlayer;
  bool _initialized = false;
  bool _disposed = false;
  int _operation = 0;
  String? _lastText;

  @override
  AssistantVoiceState build() {
    _engine = ref.watch(assistantTtsEngineProvider);
    _audioPlayer = ref.watch(assistantAudioPlayerProvider);
    ref.onDispose(() {
      _disposed = true;
      _operation += 1;
      _engine.stop();
      _stopAudioSafely();
    });
    return const AssistantVoiceState.initial();
  }

  Future<void> setEnabled(bool enabled, {required bool valuesVisible}) async {
    if (enabled && !valuesVisible) return;
    if (!enabled) await stop(clearLastText: false);
    if (!_disposed) state = state.copyWith(enabled: enabled, message: '');
  }

  Future<void> disableAndClear() async {
    await stop(clearLastText: true);
    if (!_disposed) state = state.copyWith(enabled: false, message: '');
  }

  Future<void> interrupt(AssistantVoiceInterruption reason) => switch (reason) {
    AssistantVoiceInterruption.accountChanged ||
    AssistantVoiceInterruption.financialPrivacy => disableAndClear(),
    AssistantVoiceInterruption.routeExit ||
    AssistantVoiceInterruption.appInactive => stop(),
  };

  Future<void> speak(String text, {required bool valuesVisible}) async {
    if (!state.enabled || !valuesVisible || text.trim().isEmpty) {
      await stop(clearLastText: !valuesVisible);
      return;
    }
    final int operation = ++_operation;
    _lastText = text;
    state = state.copyWith(
      phase: AssistantVoicePhase.preparing,
      message: 'Preparando leitura em português do Brasil.',
    );
    try {
      await _ensureInitialized();
      await _engine.stop();
      await _engine.setSpeed(state.speed.rate);
      await _engine.speak(text);
      if (operation == _operation && !_disposed) {
        state = state.copyWith(
          phase: AssistantVoicePhase.speaking,
          message: 'Lendo a resposta.',
        );
      }
    } on Object {
      if (operation == _operation && !_disposed) _setFailure();
    }
  }

  /// Reproduz a voz neural devolvida para o modo voz. O Future nativo só
  /// conclui quando o áudio termina, mantendo o pulso sincronizado.
  Future<void> playAudio(Uint8List bytes, {required bool valuesVisible}) async {
    if (!state.enabled || !valuesVisible || bytes.isEmpty) {
      await stop(clearLastText: !valuesVisible);
      return;
    }
    final int operation = ++_operation;
    _lastText = null;
    state = state.copyWith(
      phase: AssistantVoicePhase.preparing,
      message: 'Preparando voz natural em português do Brasil.',
    );
    try {
      await _engine.stop();
      await _audioPlayer.stop();
      if (operation != _operation || _disposed) return;
      state = state.copyWith(
        phase: AssistantVoicePhase.speaking,
        message: 'Reproduzindo a resposta.',
      );
      await _audioPlayer.play(bytes);
      if (operation == _operation && !_disposed) {
        state = state.copyWith(
          phase: AssistantVoicePhase.completed,
          message: 'Resposta concluída.',
        );
      }
    } on Object {
      if (operation == _operation && !_disposed) _setFailure();
    }
  }

  Future<void> pause() async {
    if (!state.isSpeaking) return;
    try {
      await _engine.pause();
      if (!_disposed) {
        state = state.copyWith(
          phase: AssistantVoicePhase.paused,
          message: 'Leitura pausada.',
        );
      }
    } on Object {
      _setFailure();
    }
  }

  Future<void> resume({required bool valuesVisible}) async {
    final String? text = _lastText;
    if (!state.isPaused || text == null || !valuesVisible) {
      await stop(clearLastText: !valuesVisible);
      return;
    }
    try {
      await _engine.resume(text);
      if (!_disposed) {
        state = state.copyWith(
          phase: AssistantVoicePhase.speaking,
          message: 'Leitura retomada.',
        );
      }
    } on Object {
      _setFailure();
    }
  }

  Future<void> repeat({required bool valuesVisible}) async {
    final String? text = _lastText;
    if (text != null) await speak(text, valuesVisible: valuesVisible);
  }

  Future<void> stop({bool clearLastText = false}) async {
    _operation += 1;
    if (clearLastText) _lastText = null;
    try {
      await _engine.stop();
      await _audioPlayer.stop();
    } on Object {
      // O texto continua disponível; falhas nativas nunca expõem detalhes.
    }
    if (!_disposed) {
      state = state.copyWith(phase: AssistantVoicePhase.idle, message: '');
    }
  }

  Future<void> setSpeed(AssistantVoiceSpeed speed) async {
    state = state.copyWith(speed: speed);
    if (_initialized) {
      try {
        await _engine.setSpeed(speed.rate);
      } on Object {
        _setFailure();
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _engine.initialize(
      onStart: () {
        if (!_disposed && state.phase != AssistantVoicePhase.paused) {
          state = state.copyWith(phase: AssistantVoicePhase.speaking);
        }
      },
      onComplete: () {
        if (!_disposed && state.phase != AssistantVoicePhase.idle) {
          state = state.copyWith(
            phase: AssistantVoicePhase.completed,
            message: 'Leitura concluída.',
          );
        }
      },
      onPause: () {
        if (!_disposed) {
          state = state.copyWith(phase: AssistantVoicePhase.paused);
        }
      },
      onContinue: () {
        if (!_disposed) {
          state = state.copyWith(phase: AssistantVoicePhase.speaking);
        }
      },
      onError: _setFailure,
    );
    _initialized = true;
  }

  void _setFailure() {
    if (_disposed) return;
    state = state.copyWith(
      phase: AssistantVoicePhase.failed,
      message:
          'A voz não está disponível neste momento. Você pode tentar novamente no modo texto.',
    );
  }

  Future<void> _stopAudioSafely() async {
    try {
      await _audioPlayer.stop();
    } on Object {
      // Interrupção nativa é best-effort e nunca expõe detalhes do áudio.
    }
  }
}
