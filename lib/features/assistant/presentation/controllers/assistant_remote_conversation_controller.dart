// Responsabilidade: controla a consulta remota após uma pergunta confirmada,
// preservando consentimento e privacidade antes de permitir rede.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/firebase_assistant_remote_gateway.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_grounded_response.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';

/// A aplicação só conhece a borda tipada; instanciá-la não abre conexão.
final Provider<AssistantRemoteGateway> assistantRemoteGatewayProvider =
    Provider<AssistantRemoteGateway>(
      (Ref ref) => FirebaseAssistantRemoteGateway(
        functions: FirebaseFunctions.instanceFor(
          region: FirebaseAssistantRemoteGateway.callableRegion,
        ),
      ),
    );

/// A política compilada é injetável exclusivamente para testes. Em builds do
/// aplicativo, ela delega para a flag fixa e não configurável pelo usuário.
final Provider<AssistantRemoteCallPolicy> assistantRemoteCallPolicyProvider =
    Provider<AssistantRemoteCallPolicy>(
      (Ref ref) => const CompiledAssistantRemoteCallPolicy(),
    );

abstract interface class AssistantRemoteCallPolicy {
  bool get callsEnabled;
}

final class CompiledAssistantRemoteCallPolicy
    implements AssistantRemoteCallPolicy {
  const CompiledAssistantRemoteCallPolicy();

  @override
  bool get callsEnabled => AssistantRemoteIntegrationPolicy.realCallsEnabled;
}

enum AssistantRemoteConversationPhase {
  idle,
  preparing,
  consentRequired,
  privacyBlocked,
  safeUnavailable,
  clarificationRequired,
  grounded,
}

final class AssistantRemoteConversationState {
  const AssistantRemoteConversationState({
    required this.phase,
    required this.message,
    this.response,
    this.audio,
  });

  const AssistantRemoteConversationState.initial()
    : phase = AssistantRemoteConversationPhase.idle,
      message = 'Envie uma pergunta para receber uma resposta fundamentada.',
      response = null,
      audio = null;

  final AssistantRemoteConversationPhase phase;
  final String message;
  final AssistantGroundedResponse? response;
  final AssistantRemoteAudio? audio;

  bool get isPreparing => phase == AssistantRemoteConversationPhase.preparing;

  AssistantRemoteConversationState copyWith({
    AssistantRemoteConversationPhase? phase,
    String? message,
    AssistantGroundedResponse? response,
    AssistantRemoteAudio? audio,
    bool clearResponse = false,
  }) => AssistantRemoteConversationState(
    phase: phase ?? this.phase,
    message: message ?? this.message,
    response: clearResponse ? null : response ?? this.response,
    audio: clearResponse ? null : audio ?? this.audio,
  );
}

final NotifierProvider<
  AssistantRemoteConversationController,
  AssistantRemoteConversationState
>
assistantRemoteConversationControllerProvider =
    NotifierProvider.autoDispose<
      AssistantRemoteConversationController,
      AssistantRemoteConversationState
    >(AssistantRemoteConversationController.new);

/// Descarta retornos tardios para não restaurar conteúdo após privacidade,
/// saída da tela ou mudança de conta.
final class AssistantRemoteConversationController
    extends Notifier<AssistantRemoteConversationState> {
  late AssistantRemoteGateway _gateway;
  late AssistantRemoteCallPolicy _policy;
  int _operation = 0;
  bool _disposed = false;
  AssistantRemoteContinuation? _pendingContinuation;

  @override
  AssistantRemoteConversationState build() {
    _gateway = ref.watch(assistantRemoteGatewayProvider);
    _policy = ref.watch(assistantRemoteCallPolicyProvider);
    ref.onDispose(() {
      _disposed = true;
      _operation += 1;
      _pendingContinuation = null;
    });
    return const AssistantRemoteConversationState.initial();
  }

  /// A pergunta chega somente depois do gesto de envio ou do fim da fala. O
  /// Flutter nunca monta contexto; o backend continua sendo a autoridade.
  Future<void> requestGroundedAnswer({
    required String message,
    required bool aiConsentEnabled,
    required bool remoteContextConsentAllowed,
    required bool financialValuesVisible,
    bool voiceOnly = false,
  }) async {
    if (state.isPreparing) return;
    final int operation = ++_operation;
    if (!aiConsentEnabled) {
      _pendingContinuation = null;
      _setIfCurrent(
        operation,
        const AssistantRemoteConversationState(
          phase: AssistantRemoteConversationPhase.consentRequired,
          message:
              'Confirme o consentimento de IA antes de consultar uma resposta fundamentada.',
        ),
      );
      return;
    }
    if (!remoteContextConsentAllowed) {
      _pendingContinuation = null;
      _setIfCurrent(
        operation,
        const AssistantRemoteConversationState(
          phase: AssistantRemoteConversationPhase.consentRequired,
          message:
              'Autorize o contexto financeiro remoto em Privacidade e consentimentos antes de enviar uma pergunta.',
        ),
      );
      return;
    }
    if (!financialValuesVisible) {
      _pendingContinuation = null;
      _setIfCurrent(
        operation,
        const AssistantRemoteConversationState(
          phase: AssistantRemoteConversationPhase.privacyBlocked,
          message:
              'A privacidade financeira bloqueia a consulta de resposta fundamentada.',
        ),
      );
      return;
    }
    late final AssistantRemoteRequest request;
    try {
      request = AssistantRemoteRequest(
        message: message,
        continuation: _pendingContinuation,
        responseMode: voiceOnly
            ? AssistantRemoteResponseMode.voice
            : AssistantRemoteResponseMode.text,
      );
    } on AssistantFailure {
      _pendingContinuation = null;
      _setIfCurrent(
        operation,
        const AssistantRemoteConversationState(
          phase: AssistantRemoteConversationPhase.safeUnavailable,
          message: 'Não foi possível preparar essa pergunta com segurança.',
        ),
      );
      return;
    }
    if (!_policy.callsEnabled) {
      _setIfCurrent(
        operation,
        const AssistantRemoteConversationState(
          phase: AssistantRemoteConversationPhase.safeUnavailable,
          message:
              'A resposta fundamentada está indisponível com segurança neste momento.',
        ),
      );
      return;
    }
    _setIfCurrent(
      operation,
      const AssistantRemoteConversationState(
        phase: AssistantRemoteConversationPhase.preparing,
        message: 'Preparando uma resposta fundamentada.',
      ),
    );
    try {
      final AssistantRemoteResponse result = await _gateway.ask(request);
      if (result.groundedResponse
          case final AssistantGroundedResponse response) {
        if (!_isCurrent(operation)) return;
        // Mantém somente a última pergunta, sem resposta ou valor financeiro.
        // Isso permite continuações naturais como “e no mês passado?” sem
        // transformar memória do cliente em fonte autoritativa.
        _pendingContinuation = AssistantRemoteContinuation(
          intent: 'unknown',
          clarificationCode: 'intent_ambiguous',
          previousMessage: message,
        );
        _setIfCurrent(
          operation,
          AssistantRemoteConversationState(
            phase: AssistantRemoteConversationPhase.grounded,
            message: 'Resposta fundamentada pronta para leitura.',
            response: response,
            audio: result.audio,
          ),
        );
      } else if (result.clarification
          case final AssistantRemoteClarification clarification) {
        if (!_isCurrent(operation)) return;
        _pendingContinuation = AssistantRemoteContinuation(
          intent: clarification.intent,
          clarificationCode: clarification.clarificationCode,
          previousMessage: message,
        );
        _setIfCurrent(
          operation,
          AssistantRemoteConversationState(
            phase: AssistantRemoteConversationPhase.clarificationRequired,
            message: clarification.question,
            audio: result.audio,
          ),
        );
      } else {
        _setUnavailable(operation);
      }
    } on AssistantFailure {
      _setUnavailable(operation);
    } on Object {
      _setUnavailable(operation);
    }
  }

  /// Remove resposta e invalida a operação antes de expor outra conta ou tela.
  void discard() {
    _operation += 1;
    _pendingContinuation = null;
    if (!_disposed) state = const AssistantRemoteConversationState.initial();
  }

  /// A privacidade remove qualquer resposta carregada e bloqueia nova consulta.
  void blockForFinancialPrivacy() {
    _operation += 1;
    _pendingContinuation = null;
    if (!_disposed) {
      state = const AssistantRemoteConversationState(
        phase: AssistantRemoteConversationPhase.privacyBlocked,
        message:
            'A privacidade financeira bloqueia a consulta de resposta fundamentada.',
      );
    }
  }

  void _setUnavailable(int operation) {
    if (!_isCurrent(operation)) return;
    _pendingContinuation = null;
    _setIfCurrent(
      operation,
      const AssistantRemoteConversationState(
        phase: AssistantRemoteConversationPhase.safeUnavailable,
        message:
            'A resposta fundamentada está indisponível com segurança neste momento.',
      ),
    );
  }

  bool _isCurrent(int operation) => operation == _operation && !_disposed;

  void _setIfCurrent(int operation, AssistantRemoteConversationState next) {
    if (_isCurrent(operation)) state = next;
  }
}
