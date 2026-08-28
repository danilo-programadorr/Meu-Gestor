import 'assistant_failure.dart';

enum AssistantActionKind {
  explain,
  compare,
  suggest,
  draftCreate,
  draftUpdate,
  draftArchive,
  draftCancel,
  draftVoid,
  draftDelete,
  draftReminder,
  resetFinancialData,
  deleteAccount,
  changeAuthentication,
  changeEntitlement,
  changeOwnerAccess,
}

enum AssistantActionDecision { readOnly, proposalOnly, forbidden }

abstract final class AssistantPermissionPolicy {
  static AssistantActionDecision decisionFor(
    AssistantActionKind kind,
  ) => switch (kind) {
    AssistantActionKind.explain ||
    AssistantActionKind.compare ||
    AssistantActionKind.suggest => AssistantActionDecision.readOnly,
    AssistantActionKind.draftCreate ||
    AssistantActionKind.draftUpdate ||
    AssistantActionKind.draftArchive ||
    AssistantActionKind.draftCancel ||
    AssistantActionKind.draftVoid ||
    AssistantActionKind.draftDelete ||
    AssistantActionKind.draftReminder => AssistantActionDecision.proposalOnly,
    AssistantActionKind.resetFinancialData ||
    AssistantActionKind.deleteAccount ||
    AssistantActionKind.changeAuthentication ||
    AssistantActionKind.changeEntitlement ||
    AssistantActionKind.changeOwnerAccess => AssistantActionDecision.forbidden,
  };
}

final class AssistantActionProposal {
  AssistantActionProposal({
    required this.proposalId,
    required this.kind,
    required this.targetAlias,
    required this.preview,
    required this.previewDigest,
    required this.expiresAt,
    required this.requiresExplicitConfirmation,
  }) {
    if (AssistantPermissionPolicy.decisionFor(kind) !=
            AssistantActionDecision.proposalOnly ||
        proposalId.trim().length < 16 ||
        targetAlias.trim().isEmpty ||
        preview.trim().isEmpty ||
        previewDigest.trim().length < 16 ||
        !expiresAt.isUtc ||
        !requiresExplicitConfirmation) {
      throw const AssistantFailure(AssistantFailureKind.unsupportedAction);
    }
  }

  final String proposalId;
  final AssistantActionKind kind;
  final String targetAlias;
  final String preview;
  final String previewDigest;
  final DateTime expiresAt;
  final bool requiresExplicitConfirmation;
}

final class AssistantActionConfirmation {
  const AssistantActionConfirmation({
    required this.proposalId,
    required this.previewDigest,
    required this.authenticatedUid,
    required this.ownerId,
    required this.confirmedAt,
  });

  final String proposalId;
  final String previewDigest;
  final String authenticatedUid;
  final String ownerId;
  final DateTime confirmedAt;
}

abstract final class AssistantActionConfirmationPolicy {
  static const Duration maximumAge = Duration(minutes: 5);

  static void assertConfirmed({
    required AssistantActionProposal proposal,
    required AssistantActionConfirmation confirmation,
    required DateTime serverNow,
  }) {
    if (!serverNow.isUtc || !confirmation.confirmedAt.isUtc) {
      throw const AssistantFailure(AssistantFailureKind.confirmationMismatch);
    }
    if (confirmation.authenticatedUid != confirmation.ownerId) {
      throw const AssistantFailure(AssistantFailureKind.ownerMismatch);
    }
    if (proposal.proposalId != confirmation.proposalId ||
        proposal.previewDigest != confirmation.previewDigest ||
        !proposal.requiresExplicitConfirmation) {
      throw const AssistantFailure(AssistantFailureKind.confirmationMismatch);
    }
    final Duration age = serverNow.difference(confirmation.confirmedAt);
    if (serverNow.isAfter(proposal.expiresAt) ||
        age.isNegative ||
        age > maximumAge) {
      throw const AssistantFailure(AssistantFailureKind.confirmationRequired);
    }
  }
}
