// Responsabilidade: confirma os dois consentimentos exigidos pela conversa
// remota e mantém a falha fechada até a escrita canônica ser concluída.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';

enum AssistantConversationConsentPhase {
  checking,
  required,
  activating,
  ready,
  declined,
  failed,
}

final class AssistantConversationConsentState {
  const AssistantConversationConsentState({required this.phase, this.message});

  const AssistantConversationConsentState.checking()
    : phase = AssistantConversationConsentPhase.checking,
      message = null;

  final AssistantConversationConsentPhase phase;
  final String? message;

  bool get isReady => phase == AssistantConversationConsentPhase.ready;
  bool get requiresDecision =>
      phase == AssistantConversationConsentPhase.required;
  bool get isActivating =>
      phase == AssistantConversationConsentPhase.activating;
}

final NotifierProvider<
  AssistantConversationConsentController,
  AssistantConversationConsentState
>
assistantConversationConsentControllerProvider =
    NotifierProvider.autoDispose<
      AssistantConversationConsentController,
      AssistantConversationConsentState
    >(AssistantConversationConsentController.new);

/// Coordena perfil e aceite remoto sem liberar o gateway entre as duas etapas.
final class AssistantConversationConsentController
    extends Notifier<AssistantConversationConsentState> {
  bool _checked = false;

  @override
  AssistantConversationConsentState build() =>
      const AssistantConversationConsentState.checking();

  /// O aceite é efetivo somente quando ambos os documentos foram confirmados.
  Future<void> check({required bool aiConsentEnabled}) async {
    if (_checked ||
        state.isActivating ||
        state.phase == AssistantConversationConsentPhase.declined) {
      return;
    }
    _checked = true;
    state = const AssistantConversationConsentState.checking();
    if (!aiConsentEnabled) {
      state = const AssistantConversationConsentState(
        phase: AssistantConversationConsentPhase.required,
      );
      return;
    }
    try {
      await ref.read(assistantRemoteConsentControllerProvider.notifier).load();
      state = ref.read(assistantRemoteConsentControllerProvider)
          ? const AssistantConversationConsentState(
              phase: AssistantConversationConsentPhase.ready,
            )
          : const AssistantConversationConsentState(
              phase: AssistantConversationConsentPhase.required,
            );
    } on Object {
      state = const AssistantConversationConsentState(
        phase: AssistantConversationConsentPhase.required,
      );
    }
  }

  /// Persiste primeiro o consentimento geral e, só após confirmação, o aceite
  /// remoto próprio. Falha intermediária continua fechada porque o segundo
  /// aceite permanece ausente.
  Future<void> activate({required UserProfile profile}) async {
    if (state.isActivating) return;
    state = const AssistantConversationConsentState(
      phase: AssistantConversationConsentPhase.activating,
    );
    try {
      await ref
          .read(profileActionControllerProvider.notifier)
          .updateOptionalConsents(
            aiConsentEnabled: true,
            analyticsConsentEnabled: profile.analyticsConsentEnabled,
          );
      if (ref.read(profileActionControllerProvider).status !=
          ProfileActionStatus.success) {
        _setFailure();
        return;
      }
      await ref
          .read(assistantRemoteConsentControllerProvider.notifier)
          .setAllowed(true);
      state = const AssistantConversationConsentState(
        phase: AssistantConversationConsentPhase.ready,
      );
    } on Object {
      _setFailure();
    }
  }

  /// Mantém a pessoa na conversa e não inicia nenhuma chamada remota.
  void decline() {
    state = const AssistantConversationConsentState(
      phase: AssistantConversationConsentPhase.declined,
    );
  }

  void _setFailure() {
    state = const AssistantConversationConsentState(
      phase: AssistantConversationConsentPhase.failed,
      message:
          'Não foi possível ativar o Assistente Financeiro com segurança. Tente novamente.',
    );
  }
}
