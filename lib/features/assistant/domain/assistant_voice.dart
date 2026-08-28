import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';

enum AssistantVoicePhase {
  idle,
  preparing,
  speaking,
  paused,
  completed,
  failed,
}

enum AssistantVoiceInterruption {
  routeExit,
  appInactive,
  accountChanged,
  financialPrivacy,
}

enum AssistantVoiceSpeed {
  slow(label: 'Lenta', rate: 0.4),
  normal(label: 'Normal', rate: 0.5),
  fast(label: 'Rápida', rate: 0.6);

  const AssistantVoiceSpeed({required this.label, required this.rate});

  final String label;
  final double rate;
}

final class AssistantVoiceState {
  const AssistantVoiceState({
    required this.enabled,
    required this.phase,
    required this.speed,
    required this.message,
  });

  const AssistantVoiceState.initial()
    : enabled = false,
      phase = AssistantVoicePhase.idle,
      speed = AssistantVoiceSpeed.normal,
      message = '';

  final bool enabled;
  final AssistantVoicePhase phase;
  final AssistantVoiceSpeed speed;
  final String message;

  bool get isSpeaking => phase == AssistantVoicePhase.speaking;
  bool get isPaused => phase == AssistantVoicePhase.paused;
  bool get hasPlayback =>
      phase == AssistantVoicePhase.speaking ||
      phase == AssistantVoicePhase.paused ||
      phase == AssistantVoicePhase.completed;

  AssistantVoiceState copyWith({
    bool? enabled,
    AssistantVoicePhase? phase,
    AssistantVoiceSpeed? speed,
    String? message,
  }) => AssistantVoiceState(
    enabled: enabled ?? this.enabled,
    phase: phase ?? this.phase,
    speed: speed ?? this.speed,
    message: message ?? this.message,
  );
}

abstract final class AssistantSpeechFormatter {
  static String format(AssistantDeterministicSummary summary) {
    final StringBuffer value = StringBuffer()
      ..write('${summary.title}. ')
      ..write('${summary.periodLabel}. ')
      ..write('${summary.observation} ');
    for (final AssistantSummaryMetric metric in summary.metrics) {
      value.write('${metric.label}: ');
      if (metric.moneyCents case final int cents) {
        value.write(MoneyFormatter.format(Money.fromCents(cents)));
      } else {
        value.write(metric.count);
      }
      value.write('. ');
    }
    value.write('Conteúdo informativo e somente leitura.');
    return value.toString();
  }
}
