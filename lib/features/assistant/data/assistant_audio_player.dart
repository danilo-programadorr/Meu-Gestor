// Responsabilidade: reproduzir somente o WAV efêmero admitido pelo backend,
// sem gravá-lo em armazenamento permanente nem expor seu conteúdo em logs.
import 'package:flutter/services.dart';

abstract interface class AssistantAudioPlayer {
  Future<void> play(Uint8List bytes);

  Future<void> stop();
}

final class MethodChannelAssistantAudioPlayer implements AssistantAudioPlayer {
  const MethodChannelAssistantAudioPlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName =
      'br.com.hellenfaro.meugestorfinanceiro/assistant_audio';

  final MethodChannel _channel;

  @override
  Future<void> play(Uint8List bytes) =>
      _channel.invokeMethod<void>('playWav', bytes);

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
