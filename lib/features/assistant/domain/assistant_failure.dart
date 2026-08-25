enum AssistantFailureKind {
  invalidRequest,
  unauthenticated,
  appCheckRequired,
  emailNotVerified,
  legalProfileRequired,
  ownerMismatch,
  consentRequired,
  consentNotConfirmed,
  consentVersionOutdated,
  unsafeContent,
  invalidContext,
  unsupportedAction,
  confirmationRequired,
  confirmationMismatch,
  unavailable,
}

/// Falha sanitizada: nunca carrega UID, e-mail, valor financeiro ou segredo.
final class AssistantFailure implements Exception {
  const AssistantFailure(this.kind);

  final AssistantFailureKind kind;

  String get code => switch (kind) {
    AssistantFailureKind.invalidRequest => 'assistant_invalid_request',
    AssistantFailureKind.unauthenticated => 'assistant_unauthenticated',
    AssistantFailureKind.appCheckRequired => 'assistant_app_check_required',
    AssistantFailureKind.emailNotVerified => 'assistant_email_not_verified',
    AssistantFailureKind.legalProfileRequired =>
      'assistant_legal_profile_required',
    AssistantFailureKind.ownerMismatch => 'assistant_owner_mismatch',
    AssistantFailureKind.consentRequired => 'assistant_consent_required',
    AssistantFailureKind.consentNotConfirmed =>
      'assistant_consent_not_confirmed',
    AssistantFailureKind.consentVersionOutdated =>
      'assistant_consent_version_outdated',
    AssistantFailureKind.unsafeContent => 'assistant_unsafe_content',
    AssistantFailureKind.invalidContext => 'assistant_invalid_context',
    AssistantFailureKind.unsupportedAction => 'assistant_unsupported_action',
    AssistantFailureKind.confirmationRequired =>
      'assistant_confirmation_required',
    AssistantFailureKind.confirmationMismatch =>
      'assistant_confirmation_mismatch',
    AssistantFailureKind.unavailable => 'assistant_unavailable',
  };

  String get safeMessage => switch (kind) {
    AssistantFailureKind.consentRequired ||
    AssistantFailureKind.consentNotConfirmed ||
    AssistantFailureKind.consentVersionOutdated =>
      'Revise e confirme o consentimento de IA antes de continuar.',
    AssistantFailureKind.unsafeContent =>
      'Remova senhas, tokens ou dados pessoais de terceiros e tente novamente.',
    AssistantFailureKind.confirmationRequired ||
    AssistantFailureKind.confirmationMismatch =>
      'Revise e confirme a ação antes de continuar.',
    AssistantFailureKind.unavailable =>
      'O assistente não está disponível agora. Tente novamente mais tarde.',
    _ => 'Não foi possível continuar com segurança.',
  };

  @override
  String toString() => 'AssistantFailure($code)';
}
