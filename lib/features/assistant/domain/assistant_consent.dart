import 'assistant_failure.dart';

enum AssistantMemoryMode { none, currentConversation, savedSummary }

final class AssistantAuthorizationContext {
  const AssistantAuthorizationContext({
    required this.authenticated,
    required this.appCheckVerified,
    required this.emailVerified,
    required this.legalProfileVerified,
    required this.authenticatedUid,
    required this.requestedOwnerId,
    required this.aiConsentEnabled,
    required this.acceptedPolicyVersion,
    required this.aiConsentUpdatedAt,
    required this.profileFromServer,
    required this.profileHasPendingWrites,
  });

  final bool authenticated;
  final bool appCheckVerified;
  final bool emailVerified;
  final bool legalProfileVerified;
  final String authenticatedUid;
  final String requestedOwnerId;
  final bool aiConsentEnabled;
  final String? acceptedPolicyVersion;
  final DateTime? aiConsentUpdatedAt;
  final bool profileFromServer;
  final bool profileHasPendingWrites;
}

abstract final class AssistantConsentPolicy {
  static const String currentVersion = 'assist-context-v1';

  static void assertCanUse(AssistantAuthorizationContext context) {
    if (!context.authenticated || context.authenticatedUid.trim().isEmpty) {
      throw const AssistantFailure(AssistantFailureKind.unauthenticated);
    }
    if (!context.appCheckVerified) {
      throw const AssistantFailure(AssistantFailureKind.appCheckRequired);
    }
    if (!context.emailVerified) {
      throw const AssistantFailure(AssistantFailureKind.emailNotVerified);
    }
    if (!context.legalProfileVerified) {
      throw const AssistantFailure(AssistantFailureKind.legalProfileRequired);
    }
    if (context.requestedOwnerId != context.authenticatedUid) {
      throw const AssistantFailure(AssistantFailureKind.ownerMismatch);
    }
    if (!context.aiConsentEnabled) {
      throw const AssistantFailure(AssistantFailureKind.consentRequired);
    }
    if (!context.profileFromServer || context.profileHasPendingWrites) {
      throw const AssistantFailure(AssistantFailureKind.consentNotConfirmed);
    }
    if (context.acceptedPolicyVersion != currentVersion) {
      throw const AssistantFailure(AssistantFailureKind.consentVersionOutdated);
    }
    if (context.aiConsentUpdatedAt == null ||
        !context.aiConsentUpdatedAt!.isUtc) {
      throw const AssistantFailure(AssistantFailureKind.consentNotConfirmed);
    }
  }
}

/// ASSIST-0 não persiste memória. Um resumo futuro exigirá opt-in próprio,
/// poderá reter no máximo 90 dias e deverá ser apagado na revogação do
/// consentimento ou exclusão da conta. Reset financeiro o invalida.
abstract final class AssistantMemoryPolicy {
  static const AssistantMemoryMode defaultMode = AssistantMemoryMode.none;
  static const Duration maximumSavedSummaryRetention = Duration(days: 90);

  static bool canPersist({
    required AssistantMemoryMode mode,
    required bool separateMemoryConsent,
    required bool implementationAvailable,
  }) =>
      mode == AssistantMemoryMode.savedSummary &&
      separateMemoryConsent &&
      implementationAvailable;
}
