enum PrivacyOperationFailureKind {
  invalidRequest,
  invalidConfirmation,
  unauthenticated,
  appCheckRequired,
  emailNotVerified,
  legalProfileRequired,
  recentAuthenticationRequired,
  ownerMismatch,
  operationNotFound,
  operationInProgress,
  operationConflict,
  invalidTransition,
  unavailable,
  timeout,
  inconsistentState,
}

/// Falha de fronteira que pode ser apresentada sem revelar UID, estado interno
/// de deleção, documentos, token ou detalhes de autenticação.
final class PrivacyOperationFailure implements Exception {
  const PrivacyOperationFailure(this.kind);

  final PrivacyOperationFailureKind kind;

  String get code => switch (kind) {
    PrivacyOperationFailureKind.invalidRequest => 'privacy_invalid_request',
    PrivacyOperationFailureKind.invalidConfirmation =>
      'privacy_invalid_confirmation',
    PrivacyOperationFailureKind.unauthenticated => 'privacy_unauthenticated',
    PrivacyOperationFailureKind.appCheckRequired =>
      'privacy_app_check_required',
    PrivacyOperationFailureKind.emailNotVerified =>
      'privacy_email_not_verified',
    PrivacyOperationFailureKind.legalProfileRequired =>
      'privacy_legal_profile_required',
    PrivacyOperationFailureKind.recentAuthenticationRequired =>
      'privacy_recent_authentication_required',
    PrivacyOperationFailureKind.ownerMismatch => 'privacy_owner_mismatch',
    PrivacyOperationFailureKind.operationNotFound =>
      'privacy_operation_not_found',
    PrivacyOperationFailureKind.operationInProgress =>
      'privacy_operation_in_progress',
    PrivacyOperationFailureKind.operationConflict =>
      'privacy_operation_conflict',
    PrivacyOperationFailureKind.invalidTransition =>
      'privacy_invalid_transition',
    PrivacyOperationFailureKind.unavailable => 'privacy_unavailable',
    PrivacyOperationFailureKind.timeout => 'privacy_timeout',
    PrivacyOperationFailureKind.inconsistentState =>
      'privacy_inconsistent_state',
  };

  String get safeMessage => switch (kind) {
    PrivacyOperationFailureKind.invalidConfirmation =>
      'Confirme a operação novamente antes de continuar.',
    PrivacyOperationFailureKind.recentAuthenticationRequired =>
      'Confirme sua identidade novamente para continuar.',
    PrivacyOperationFailureKind.operationInProgress =>
      'A operação já está em andamento.',
    PrivacyOperationFailureKind.timeout ||
    PrivacyOperationFailureKind.unavailable =>
      'Não foi possível concluir agora. Tente novamente mais tarde.',
    _ => 'Não foi possível concluir esta operação com segurança.',
  };

  @override
  String toString() => 'PrivacyOperationFailure($code)';
}
