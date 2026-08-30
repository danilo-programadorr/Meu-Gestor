import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';

/// Estado local e efêmero do reconhecimento nativo; nunca representa áudio.
enum AssistantConversationPhase {
  ready,
  requestingPermission,
  listening,
  thinking,
  speaking,
  unavailable,
  permissionDenied,
  failed,
}

/// Parâmetros visuais verificáveis do modo de conversa.
abstract final class AssistantConversationVisualConfig {
  static const int particleCount = 30;
}

final class AssistantConversationState {
  const AssistantConversationState({
    required this.phase,
    required this.transcript,
    required this.message,
    required this.voiceIntensity,
    this.question,
  });

  const AssistantConversationState.initial()
    : phase = AssistantConversationPhase.ready,
      transcript = '',
      message = 'Pronto para uma pergunta por voz.',
      voiceIntensity = 0,
      question = null;

  final AssistantConversationPhase phase;
  final String transcript;
  final String message;

  /// Intensidade efêmera do reconhecimento nativo, normalizada entre zero e um.
  /// Não representa áudio e nunca é persistida.
  final double voiceIntensity;
  final AssistantGuidedQuestion? question;

  AssistantConversationState copyWith({
    AssistantConversationPhase? phase,
    String? transcript,
    String? message,
    double? voiceIntensity,
    AssistantGuidedQuestion? question,
    bool clearQuestion = false,
  }) => AssistantConversationState(
    phase: phase ?? this.phase,
    transcript: transcript ?? this.transcript,
    message: message ?? this.message,
    voiceIntensity: voiceIntensity ?? this.voiceIntensity,
    question: clearQuestion ? null : question ?? this.question,
  );
}

abstract final class AssistantConversationQuestionMatcher {
  /// Aceita apenas intenções determinísticas já disponíveis no Assistente.
  static AssistantGuidedQuestion? match(String transcript) {
    final String normalized = transcript
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u');
    if (normalized.contains('saldo')) {
      return AssistantGuidedQuestion.currentBalance;
    }
    if (normalized.contains('pendenc') ||
        normalized.contains('pagar') ||
        normalized.contains('receber')) {
      return AssistantGuidedQuestion.commitmentStatus;
    }
    if (normalized.contains('invest')) {
      return AssistantGuidedQuestion.investmentOverview;
    }
    if (normalized.contains('mes') ||
        normalized.contains('receita') ||
        normalized.contains('despesa')) {
      return AssistantGuidedQuestion.monthlyOverview;
    }
    return null;
  }
}
