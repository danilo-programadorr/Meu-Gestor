import 'package:flutter_tts/flutter_tts.dart';

typedef AssistantTtsCallback = void Function();
typedef AssistantTtsErrorCallback = void Function();

abstract interface class AssistantTtsEngine {
  Future<void> initialize({
    required AssistantTtsCallback onStart,
    required AssistantTtsCallback onComplete,
    required AssistantTtsCallback onPause,
    required AssistantTtsCallback onContinue,
    required AssistantTtsErrorCallback onError,
  });

  Future<void> speak(String text);
  Future<void> pause();
  Future<void> resume(String text);
  Future<void> stop();
  Future<void> setSpeed(double rate);
}

final class FlutterAssistantTtsEngine implements AssistantTtsEngine {
  FlutterAssistantTtsEngine({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<void> initialize({
    required AssistantTtsCallback onStart,
    required AssistantTtsCallback onComplete,
    required AssistantTtsCallback onPause,
    required AssistantTtsCallback onContinue,
    required AssistantTtsErrorCallback onError,
  }) async {
    _flutterTts.setStartHandler(onStart);
    _flutterTts.setCompletionHandler(onComplete);
    _flutterTts.setPauseHandler(onPause);
    _flutterTts.setContinueHandler(onContinue);
    _flutterTts.setCancelHandler(onComplete);
    _flutterTts.setErrorHandler((_) => onError());
    final bool available =
        await _flutterTts.isLanguageAvailable('pt-BR') == true;
    if (!available) throw StateError('assistant_pt_br_voice_unavailable');
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setVolume(1);
    await _flutterTts.setPitch(1);
    await _flutterTts.awaitSpeakCompletion(false);
  }

  @override
  Future<void> speak(String text) async {
    final dynamic result = await _flutterTts.speak(text);
    if (result != 1) throw StateError('assistant_tts_start_failed');
  }

  @override
  Future<void> pause() async {
    final dynamic result = await _flutterTts.pause();
    if (result != 1) throw StateError('assistant_tts_pause_failed');
  }

  @override
  Future<void> resume(String text) => speak(text);

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  @override
  Future<void> setSpeed(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }
}
