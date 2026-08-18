import 'privacy_operation.dart';
import 'privacy_operation_failure.dart';

/// Contexto que o futuro backend deriva de credenciais verificadas e do seu
/// próprio relógio. Nenhum campo é obtido do relógio, UID ou App Check do app.
final class PrivacyOperationAuthorization {
  const PrivacyOperationAuthorization({
    required this.authenticated,
    required this.appCheckVerified,
    required this.emailVerified,
    required this.legalProfileVerified,
    required this.authenticatedUid,
    required this.authenticatedAt,
    required this.serverNow,
  });

  final bool authenticated;
  final bool appCheckVerified;
  final bool emailVerified;
  final bool legalProfileVerified;
  final String? authenticatedUid;
  final DateTime? authenticatedAt;
  final DateTime serverNow;
}

final class PrivacyOperationPolicy {
  const PrivacyOperationPolicy();

  static const Duration maximumAuthenticationAge = Duration(minutes: 5);

  void assertCanStart({
    required PrivacyOperationType type,
    required String confirmationPhrase,
    required String requestedOwnerId,
    required PrivacyOperationAuthorization authorization,
  }) {
    if (!authorization.authenticated ||
        authorization.authenticatedUid == null) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.unauthenticated,
      );
    }
    if (!authorization.appCheckVerified) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.appCheckRequired,
      );
    }
    if (!authorization.emailVerified) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.emailNotVerified,
      );
    }
    if (!authorization.legalProfileVerified) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.legalProfileRequired,
      );
    }
    if (authorization.authenticatedUid != requestedOwnerId) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.ownerMismatch,
      );
    }
    final DateTime? authenticatedAt = authorization.authenticatedAt;
    if (authenticatedAt == null ||
        !authenticatedAt.isUtc ||
        !authorization.serverNow.isUtc ||
        authenticatedAt.isAfter(authorization.serverNow) ||
        authorization.serverNow.difference(authenticatedAt) >
            maximumAuthenticationAge) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.recentAuthenticationRequired,
      );
    }
    if (confirmationPhrase != type.confirmationPhrase) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidConfirmation,
      );
    }
  }

  PrivacyOperationState transition({
    required PrivacyOperation operation,
    required PrivacyOperationState next,
  }) {
    if (operation.isTerminal || next == PrivacyOperationState.prepared) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidTransition,
      );
    }
    if (next == PrivacyOperationState.retryableFailure) {
      return next;
    }
    final PrivacyOperationState current = operation.state;
    final bool allowed = switch ((current, next)) {
      (PrivacyOperationState.prepared, PrivacyOperationState.confirmed) => true,
      (PrivacyOperationState.confirmed, PrivacyOperationState.writeLocked) =>
        true,
      (
        PrivacyOperationState.writeLocked,
        PrivacyOperationState.deletingFinancialData,
      ) =>
        true,
      (
        PrivacyOperationState.deletingFinancialData,
        PrivacyOperationState.completed,
      )
          when operation.type == PrivacyOperationType.financialReset =>
        true,
      (
        PrivacyOperationState.deletingFinancialData,
        PrivacyOperationState.deletingIdentityData,
      )
          when operation.type == PrivacyOperationType.accountDeletion =>
        true,
      (
        PrivacyOperationState.deletingIdentityData,
        PrivacyOperationState.authenticationDeletionPending,
      ) =>
        true,
      (
        PrivacyOperationState.authenticationDeletionPending,
        PrivacyOperationState.completed,
      ) =>
        true,
      (PrivacyOperationState.retryableFailure, PrivacyOperationState.confirmed)
          when operation.resumeState == PrivacyOperationState.confirmed =>
        true,
      (
        PrivacyOperationState.retryableFailure,
        PrivacyOperationState.writeLocked,
      )
          when operation.resumeState == PrivacyOperationState.writeLocked =>
        true,
      (
        PrivacyOperationState.retryableFailure,
        PrivacyOperationState.deletingFinancialData,
      )
          when operation.resumeState ==
              PrivacyOperationState.deletingFinancialData =>
        true,
      (
        PrivacyOperationState.retryableFailure,
        PrivacyOperationState.deletingIdentityData,
      )
          when operation.resumeState ==
              PrivacyOperationState.deletingIdentityData =>
        true,
      (
        PrivacyOperationState.retryableFailure,
        PrivacyOperationState.authenticationDeletionPending,
      )
          when operation.resumeState ==
              PrivacyOperationState.authenticationDeletionPending =>
        true,
      _ => false,
    };
    if (!allowed) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidTransition,
      );
    }
    return next;
  }
}
