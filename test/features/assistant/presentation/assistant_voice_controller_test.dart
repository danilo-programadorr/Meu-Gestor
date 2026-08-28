import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_tts_engine.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_voice.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_voice_controller.dart';

void main() {
  test(
    'voz começa desligada e usa pt-BR somente após opção explícita',
    () async {
      final _FakeTtsEngine engine = _FakeTtsEngine();
      final ProviderContainer container = _container(engine);
      addTearDown(container.dispose);
      final AssistantVoiceController controller = container.read(
        assistantVoiceControllerProvider.notifier,
      );

      expect(container.read(assistantVoiceControllerProvider).enabled, isFalse);
      await controller.speak('não deve tocar', valuesVisible: true);
      expect(engine.spoken, isEmpty);

      await controller.setEnabled(true, valuesVisible: true);
      await controller.speak('resposta segura', valuesVisible: true);
      expect(engine.initializations, 1);
      expect(engine.spoken, <String>['resposta segura']);
      expect(
        container.read(assistantVoiceControllerProvider).isSpeaking,
        isTrue,
      );
    },
  );

  test('privacidade bloqueia conteúdo e descarta repetição', () async {
    final _FakeTtsEngine engine = _FakeTtsEngine();
    final ProviderContainer container = _container(engine);
    addTearDown(container.dispose);
    final AssistantVoiceController controller = container.read(
      assistantVoiceControllerProvider.notifier,
    );

    await controller.setEnabled(true, valuesVisible: true);
    await controller.speak('saldo 100', valuesVisible: true);
    await controller.disableAndClear();
    await controller.setEnabled(true, valuesVisible: false);
    await controller.speak('saldo oculto', valuesVisible: false);
    await controller.repeat(valuesVisible: true);

    expect(engine.spoken, <String>['saldo 100']);
    expect(engine.stopCalls, greaterThanOrEqualTo(2));
    expect(container.read(assistantVoiceControllerProvider).enabled, isFalse);
  });

  test('pausa, continua, repete, muda velocidade e para', () async {
    final _FakeTtsEngine engine = _FakeTtsEngine();
    final ProviderContainer container = _container(engine);
    addTearDown(container.dispose);
    final AssistantVoiceController controller = container.read(
      assistantVoiceControllerProvider.notifier,
    );

    await controller.setEnabled(true, valuesVisible: true);
    await controller.speak('resposta', valuesVisible: true);
    await controller.pause();
    expect(container.read(assistantVoiceControllerProvider).isPaused, isTrue);
    await controller.resume(valuesVisible: true);
    await controller.setSpeed(AssistantVoiceSpeed.fast);
    await controller.repeat(valuesVisible: true);
    await controller.stop();

    expect(engine.pauseCalls, 1);
    expect(engine.resumeCalls, 1);
    expect(engine.speeds, contains(AssistantVoiceSpeed.fast.rate));
    expect(engine.spoken, hasLength(2));
    expect(
      container.read(assistantVoiceControllerProvider).phase,
      AssistantVoicePhase.idle,
    );
  });

  test('falha nativa é sanitizada e preserva resposta escrita', () async {
    final _FakeTtsEngine engine = _FakeTtsEngine(failInitialization: true);
    final ProviderContainer container = _container(engine);
    addTearDown(container.dispose);
    final AssistantVoiceController controller = container.read(
      assistantVoiceControllerProvider.notifier,
    );

    await controller.setEnabled(true, valuesVisible: true);
    await controller.speak('resposta', valuesVisible: true);

    final AssistantVoiceState state = container.read(
      assistantVoiceControllerProvider,
    );
    expect(state.phase, AssistantVoicePhase.failed);
    expect(state.message, contains('resposta escrita permanece visível'));
    expect(state.message, isNot(contains('native-secret')));
  });

  test(
    'fronteiras de conta e privacidade desligam e descartam a fala',
    () async {
      for (final AssistantVoiceInterruption reason
          in <AssistantVoiceInterruption>[
            AssistantVoiceInterruption.accountChanged,
            AssistantVoiceInterruption.financialPrivacy,
          ]) {
        final _FakeTtsEngine engine = _FakeTtsEngine();
        final ProviderContainer container = _container(engine);
        final AssistantVoiceController controller = container.read(
          assistantVoiceControllerProvider.notifier,
        );
        await controller.setEnabled(true, valuesVisible: true);
        await controller.speak('dado financeiro', valuesVisible: true);
        await controller.interrupt(reason);
        await controller.repeat(valuesVisible: true);
        expect(
          container.read(assistantVoiceControllerProvider).enabled,
          isFalse,
        );
        expect(engine.spoken, <String>['dado financeiro']);
        container.dispose();
      }
    },
  );

  test('saída da rota e bloqueio param sem descartar a preferência', () async {
    for (final AssistantVoiceInterruption reason
        in <AssistantVoiceInterruption>[
          AssistantVoiceInterruption.routeExit,
          AssistantVoiceInterruption.appInactive,
        ]) {
      final _FakeTtsEngine engine = _FakeTtsEngine();
      final ProviderContainer container = _container(engine);
      final AssistantVoiceController controller = container.read(
        assistantVoiceControllerProvider.notifier,
      );
      await controller.setEnabled(true, valuesVisible: true);
      await controller.speak('resposta', valuesVisible: true);
      await controller.interrupt(reason);
      expect(container.read(assistantVoiceControllerProvider).enabled, isTrue);
      expect(
        container.read(assistantVoiceControllerProvider).phase,
        AssistantVoicePhase.idle,
      );
      container.dispose();
    }
  });
}

ProviderContainer _container(_FakeTtsEngine engine) => ProviderContainer(
  overrides: [assistantTtsEngineProvider.overrideWithValue(engine)],
);

final class _FakeTtsEngine implements AssistantTtsEngine {
  _FakeTtsEngine({this.failInitialization = false});

  final bool failInitialization;
  int initializations = 0;
  int stopCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  final List<String> spoken = <String>[];
  final List<double> speeds = <double>[];

  @override
  Future<void> initialize({
    required AssistantTtsCallback onStart,
    required AssistantTtsCallback onComplete,
    required AssistantTtsCallback onPause,
    required AssistantTtsCallback onContinue,
    required AssistantTtsErrorCallback onError,
  }) async {
    initializations += 1;
    if (failInitialization) throw StateError('native-secret');
  }

  @override
  Future<void> pause() async => pauseCalls += 1;

  @override
  Future<void> resume(String text) async => resumeCalls += 1;

  @override
  Future<void> setSpeed(double rate) async => speeds.add(rate);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls += 1;
}
