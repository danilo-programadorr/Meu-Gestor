import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_contract.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_failure.dart';

/// Cliente das callables privadas. Não grava Firestore e não considera uma
/// resposta local/cache como confirmação da operação.
final class FirebasePrivacyOperationRepository
    implements PrivacyOperationRepository {
  FirebasePrivacyOperationRepository({
    required FirebaseFunctions functions,
    required FirebaseAuth auth,
  }) : _functions = functions,
       _auth = auth;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<PrivacyOperationSnapshot> request(
    PrivacyOperationStartCommand command,
  ) => _invoke(
    name: 'preparePrivacyOperation',
    data: <String, Object>{
      'type': command.type.name,
      'confirmationPhrase': command.confirmationPhrase,
      'idempotencyKey': command.idempotencyKey.value,
    },
  );

  @override
  Future<PrivacyOperationSnapshot> retry(PrivacyOperationId operationId) =>
      _invoke(
        name: 'confirmPrivacyOperation',
        data: <String, Object>{'operationId': operationId.value},
      );

  @override
  Future<PrivacyOperationSnapshot> status(PrivacyOperationId operationId) =>
      _invoke(
        name: 'getPrivacyOperationStatus',
        data: <String, Object>{'operationId': operationId.value},
        refreshIdentity: false,
      );

  Future<PrivacyOperationSnapshot> _invoke({
    required String name,
    required Map<String, Object> data,
    bool refreshIdentity = true,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw const PrivacyOperationFailure(
          PrivacyOperationFailureKind.unauthenticated,
        );
      }
      // A renovação ocorre após reautenticação nas chamadas mutáveis. O
      // polling usa o token já emitido para ainda receber o recibo anônimo
      // depois que a exclusão do usuário no Auth tiver sido concluída.
      if (refreshIdentity) await user.getIdToken(true);
      final HttpsCallableResult<Object?> response = await _functions
          .httpsCallable(name)
          .call<Object?>(data);
      return parseResponse(response.data, user.uid);
    } on PrivacyOperationFailure {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw PrivacyOperationFailure(_mapFailure(error));
    } on FirebaseAuthException {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.unauthenticated,
      );
    } on Object {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.unavailable,
      );
    }
  }

  /// Parser compartilhado pelos testes de contrato servidor → Flutter.
  static PrivacyOperationSnapshot parseResponse(Object? value, String ownerId) {
    if (value is! Map<Object?, Object?>) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    final Map<String, Object?> data = Map<String, Object?>.from(value);
    final String? id = data['operationId'] as String?;
    final String? type = data['type'] as String?;
    final String? state = data['state'] as String?;
    if (id == null || type == null || state == null) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    final PrivacyOperationId operationId = PrivacyOperationId(id);
    final PrivacyOperationType operationType;
    try {
      operationType = PrivacyOperationType.values.byName(type);
    } on ArgumentError {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    if (state == 'completed') {
      final Object? rawReceipt = data['receipt'];
      if (rawReceipt is! Map<Object?, Object?>) {
        throw const PrivacyOperationFailure(
          PrivacyOperationFailureKind.inconsistentState,
        );
      }
      final Map<String, Object?> receipt = Map<String, Object?>.from(
        rawReceipt,
      );
      final DateTime? completedAt = _serverDate(receipt['completedAt']);
      final DateTime? expiresAt = _serverDate(receipt['expiresAt']);
      final String? receiptId = receipt['receiptId'] as String?;
      final String? receiptType = receipt['type'] as String?;
      final String? result = receipt['result'] as String?;
      if (receiptId == null ||
          receiptType != type ||
          completedAt == null ||
          expiresAt == null) {
        throw const PrivacyOperationFailure(
          PrivacyOperationFailureKind.inconsistentState,
        );
      }
      final PrivacyOperationResult operationResult = switch (result) {
        'resetCompleted' => PrivacyOperationResult.resetCompleted,
        'accountDeleted' => PrivacyOperationResult.accountDeleted,
        _ => throw const PrivacyOperationFailure(
          PrivacyOperationFailureKind.inconsistentState,
        ),
      };
      return PrivacyOperationSnapshot.completed(
        operationId: operationId,
        type: operationType,
        receipt: AnonymousPrivacyReceipt.fromServer(
          receiptId: receiptId,
          type: operationType,
          result: operationResult,
          completedAt: completedAt,
          expiresAt: expiresAt,
        ),
      );
    }
    final int? revision = data['revision'] as int?;
    final DateTime? createdAt = _serverDate(data['createdAt']);
    final DateTime? updatedAt = _serverDate(data['updatedAt']);
    if (revision == null || createdAt == null || updatedAt == null) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    return PrivacyOperationSnapshot.active(
      PrivacyOperation(
        id: operationId,
        type: operationType,
        ownerId: ownerId,
        state: _stateFor(state),
        revision: revision,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  static DateTime? _serverDate(Object? value) => switch (value) {
    final String value => DateTime.tryParse(value)?.toUtc(),
    final DateTime value => value.toUtc(),
    _ => null,
  };

  static PrivacyOperationState _stateFor(String value) => switch (value) {
    'prepared' => PrivacyOperationState.prepared,
    'confirmed' => PrivacyOperationState.confirmed,
    'locked' => PrivacyOperationState.writeLocked,
    'deleting' => PrivacyOperationState.deletingFinancialData,
    'authDeletionPending' =>
      PrivacyOperationState.authenticationDeletionPending,
    'failed' => PrivacyOperationState.retryableFailure,
    _ => throw const PrivacyOperationFailure(
      PrivacyOperationFailureKind.inconsistentState,
    ),
  };

  PrivacyOperationFailureKind _mapFailure(FirebaseFunctionsException error) {
    final Object? details = error.details;
    if (details is Map && details['privacyCode'] is String) {
      return switch (details['privacyCode']) {
        'privacy_unauthenticated' =>
          PrivacyOperationFailureKind.unauthenticated,
        'privacy_app_check_required' =>
          PrivacyOperationFailureKind.appCheckRequired,
        'privacy_email_not_verified' =>
          PrivacyOperationFailureKind.emailNotVerified,
        'privacy_legal_profile_required' =>
          PrivacyOperationFailureKind.legalProfileRequired,
        'privacy_recent_authentication_required' =>
          PrivacyOperationFailureKind.recentAuthenticationRequired,
        'privacy_invalid_confirmation' =>
          PrivacyOperationFailureKind.invalidConfirmation,
        'privacy_operation_not_found' =>
          PrivacyOperationFailureKind.operationNotFound,
        'privacy_operation_in_progress' =>
          PrivacyOperationFailureKind.operationInProgress,
        'privacy_operation_conflict' =>
          PrivacyOperationFailureKind.operationConflict,
        'privacy_invalid_transition' =>
          PrivacyOperationFailureKind.invalidTransition,
        'privacy_authorization_denied' =>
          PrivacyOperationFailureKind.ownerMismatch,
        _ => PrivacyOperationFailureKind.unavailable,
      };
    }
    return switch (error.code) {
      'unauthenticated' => PrivacyOperationFailureKind.unauthenticated,
      'permission-denied' => PrivacyOperationFailureKind.legalProfileRequired,
      'failed-precondition' => PrivacyOperationFailureKind.unavailable,
      'deadline-exceeded' => PrivacyOperationFailureKind.timeout,
      'invalid-argument' => PrivacyOperationFailureKind.invalidRequest,
      _ => PrivacyOperationFailureKind.unavailable,
    };
  }
}
