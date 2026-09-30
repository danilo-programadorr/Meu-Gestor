import 'package:flutter_tts/flutter_tts.dart';

/// Perfil nativo: prefere a voz feminina pt-BR mais natural exposta pelo
/// mecanismo Android, inclusive a variante de rede, e mantém a local como
/// fallback para indisponibilidade de conectividade.
abstract final class AssistantTtsVoiceProfile {
  static const String locale = 'pt-BR';
  static const String preferredAndroidEngine = 'com.google.android.tts';
  static const double pitch = 1.02;
}

/// Seleciona deterministicamente a melhor voz feminina informada pelo Android.
/// Nomes sem marcador de gênero não são adivinhados como femininos.
abstract final class AssistantTtsVoiceSelector {
  static Map<String, String>? select(Object? rawVoices) {
    if (rawVoices is! Iterable<Object?>) return null;
    final List<({Map<String, String> voice, int score})> candidates = [];
    for (final Object? rawVoice in rawVoices) {
      if (rawVoice is! Map<Object?, Object?>) continue;
      final String? name = rawVoice['name']?.toString().trim();
      final String? locale = rawVoice['locale']?.toString().trim();
      if (name == null || name.isEmpty || !_isBrazilianPortuguese(locale)) {
        continue;
      }
      final String normalizedName = name.toLowerCase();
      if (!_isExplicitlyFemale(normalizedName) ||
          _isExplicitlyMale(normalizedName)) {
        continue;
      }
      final String quality =
          rawVoice['quality']?.toString().toLowerCase() ?? '';
      final String networkValue =
          rawVoice['network_required']?.toString().toLowerCase() ?? '';
      final bool networkRequired =
          networkValue == '1' || networkValue == 'true';
      final int qualityScore = switch (quality) {
        'very high' => 400,
        'high' => 300,
        'normal' => 200,
        'low' => 100,
        'very low' => 0,
        _ => 150,
      };
      candidates.add((
        voice: <String, String>{
          'name': name,
          'locale': AssistantTtsVoiceProfile.locale,
        },
        // O mecanismo Google fornece as vozes de rede com síntese mais
        // natural. A qualidade declarada continua decidindo dentro do grupo.
        score: qualityScore + (networkRequired ? 1_000 : 0),
      ));
    }
    candidates.sort((left, right) {
      final int byScore = right.score.compareTo(left.score);
      return byScore != 0
          ? byScore
          : left.voice['name']!.compareTo(right.voice['name']!);
    });
    return candidates.isEmpty ? null : candidates.first.voice;
  }

  static bool _isBrazilianPortuguese(String? locale) =>
      locale?.replaceAll('_', '-').toLowerCase() == 'pt-br';

  static bool _isExplicitlyFemale(String name) => RegExp(
    r'(^|[-_#])(female(?:_\d+)?|feminina|afs)([-_#]|$)',
  ).hasMatch(name);

  static bool _isExplicitlyMale(String name) =>
      RegExp(r'(^|[-_#])(male(?:_\d+)?|masculina|ptd)([-_#]|$)').hasMatch(name);
}

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
    await _preferNaturalAndroidEngine();
    final bool available =
        await _flutterTts.isLanguageAvailable(
          AssistantTtsVoiceProfile.locale,
        ) ==
        true;
    if (!available) throw StateError('assistant_pt_br_voice_unavailable');
    await _flutterTts.setLanguage(AssistantTtsVoiceProfile.locale);
    await _selectInstalledFemaleVoice();
    await _flutterTts.setVolume(1);
    await _flutterTts.setPitch(AssistantTtsVoiceProfile.pitch);
    await _flutterTts.awaitSpeakCompletion(false);
  }

  Future<void> _preferNaturalAndroidEngine() async {
    try {
      final Object? engines = await _flutterTts.getEngines;
      if (engines is Iterable<Object?> &&
          engines.any(
            (Object? engine) =>
                engine?.toString() ==
                AssistantTtsVoiceProfile.preferredAndroidEngine,
          )) {
        await _flutterTts.setEngine(
          AssistantTtsVoiceProfile.preferredAndroidEngine,
        );
      }
    } on Object {
      // A voz padrão do aparelho continua sendo um fallback funcional.
    }
  }

  Future<void> _selectInstalledFemaleVoice() async {
    try {
      final Map<String, String>? voice = AssistantTtsVoiceSelector.select(
        await _flutterTts.getVoices,
      );
      if (voice == null) throw StateError('assistant_female_voice_unavailable');
      final dynamic selected = await _flutterTts.setVoice(voice);
      if (selected != 1) {
        throw StateError('assistant_female_voice_not_selected');
      }
    } on StateError {
      rethrow;
    } on Object {
      throw StateError('assistant_female_voice_selection_failed');
    }
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
