import 'privacy_data_manifest.dart';
import 'privacy_operation_failure.dart';

enum PrivacyOperationType {
  financialReset,
  accountDeletion;

  String get confirmationPhrase => switch (this) {
    PrivacyOperationType.financialReset => 'RESETAR DADOS FINANCEIROS',
    PrivacyOperationType.accountDeletion => 'EXCLUIR MINHA CONTA',
  };
}

enum PrivacyOperationState {
  prepared,
  confirmed,
  writeLocked,
  deletingFinancialData,
  deletingIdentityData,
  authenticationDeletionPending,
  retryableFailure,
  completed,
}

enum PrivacyOperationResult { resetCompleted, accountDeleted }

/// Identificador opaco emitido pelo servidor. Não deve conter UID ou e-mail.
final class PrivacyOperationId {
  PrivacyOperationId(this.value) {
    if (value.trim().length < 16) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidRequest,
      );
    }
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is PrivacyOperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Chave opaca e estável por intenção do usuário para dar idempotência à
/// solicitação. O servidor decide seu escopo e nunca a inclui no recibo.
final class PrivacyIdempotencyKey {
  PrivacyIdempotencyKey(this.value) {
    if (value.trim().length < 16) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidRequest,
      );
    }
  }

  final String value;
}

final class PrivacyDeletionCursor {
  PrivacyDeletionCursor({
    required this.target,
    required this.deletedCount,
    this.lastProcessedDocument,
  }) {
    if (deletedCount < 0) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidRequest,
      );
    }
  }

  final PrivacyDataTarget target;
  final int deletedCount;

  /// Cursor técnico privado do backend; nunca é uma resposta de interface.
  final String? lastProcessedDocument;
}

/// Estado persistível futuro de uma operação em curso. O UID só existe até o
/// término; um resultado concluído é materializado como recibo anônimo.
final class PrivacyOperation {
  PrivacyOperation({
    required this.id,
    required this.type,
    required this.ownerId,
    required this.state,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.cursor,
    this.resumeState,
  }) {
    if (ownerId.trim().isEmpty ||
        revision < 1 ||
        !createdAt.isUtc ||
        !updatedAt.isUtc) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidRequest,
      );
    }
    if (updatedAt.isBefore(createdAt) ||
        (state == PrivacyOperationState.retryableFailure &&
            resumeState == null) ||
        (state != PrivacyOperationState.retryableFailure &&
            resumeState != null) ||
        state == PrivacyOperationState.completed ||
        resumeState == PrivacyOperationState.prepared ||
        resumeState == PrivacyOperationState.retryableFailure ||
        resumeState == PrivacyOperationState.completed ||
        (type == PrivacyOperationType.financialReset &&
            (state == PrivacyOperationState.deletingIdentityData ||
                state ==
                    PrivacyOperationState.authenticationDeletionPending))) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
  }

  final PrivacyOperationId id;
  final PrivacyOperationType type;
  final String ownerId;
  final PrivacyOperationState state;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PrivacyDeletionCursor? cursor;
  final PrivacyOperationState? resumeState;

  bool get isTerminal => state == PrivacyOperationState.completed;
}

/// Recibo sem UID, e-mail, operação, chave de idempotência ou dados apagados.
final class AnonymousPrivacyReceipt {
  AnonymousPrivacyReceipt._({
    required this.receiptId,
    required this.type,
    required this.result,
    required this.completedAt,
    required this.expiresAt,
  });

  factory AnonymousPrivacyReceipt.create({
    required String receiptId,
    required PrivacyOperationType type,
    required PrivacyOperationResult result,
    required DateTime completedAt,
  }) {
    final bool hasExpectedResult =
        (type == PrivacyOperationType.financialReset &&
            result == PrivacyOperationResult.resetCompleted) ||
        (type == PrivacyOperationType.accountDeletion &&
            result == PrivacyOperationResult.accountDeleted);
    if (receiptId.trim().length < 16 ||
        !completedAt.isUtc ||
        !hasExpectedResult) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.invalidRequest,
      );
    }
    return AnonymousPrivacyReceipt._(
      receiptId: receiptId,
      type: type,
      result: result,
      completedAt: completedAt,
      expiresAt: completedAt.add(plannedRetention),
    );
  }

  static const Duration plannedRetention = Duration(days: 30);

  final String receiptId;
  final PrivacyOperationType type;
  final PrivacyOperationResult result;
  final DateTime completedAt;
  final DateTime expiresAt;
}
