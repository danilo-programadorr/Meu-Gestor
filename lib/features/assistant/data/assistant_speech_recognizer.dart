import 'package:flutter/services.dart';

abstract interface class AssistantSpeechRecognizer {
  Future<bool> isAvailable();
  Future<bool> hasMicrophonePermission();
  Stream<double> get rmsLevels;
  Future<String> listen();
  Future<void> stop();
}

final class AssistantSpeechException implements Exception {
  const AssistantSpeechException(this.code);
  final String code;
}

/// Ponte mínima para o reconhecedor configurado no Android. Não usa rede própria.
final class MethodChannelAssistantSpeechRecognizer
    implements AssistantSpeechRecognizer {
  const MethodChannelAssistantSpeechRecognizer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'br.com.hellenfaro.meugestorfinanceiro/assistant_speech';
  static const String _rmsChannelName =
      'br.com.hellenfaro.meugestorfinanceiro/assistant_speech_rms';
  final MethodChannel _channel;

  @override
  Stream<double> get rmsLevels => const EventChannel(_rmsChannelName)
      .receiveBroadcastStream()
      .where((dynamic value) => value is num)
      .map((dynamic value) => (value as num).toDouble());

  @override
  Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<bool> hasMicrophonePermission() async =>
      await _channel.invokeMethod<bool>('hasMicrophonePermission') ?? false;

  @override
  Future<String> listen() async {
    try {
      final String? transcript = await _channel.invokeMethod<String>(
        'startListening',
      );
      final String value = transcript?.trim() ?? '';
      if (value.isEmpty) throw const AssistantSpeechException('no_match');
      return value;
    } on PlatformException catch (error) {
      throw AssistantSpeechException(error.code);
    }
  }

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stopListening');
}
