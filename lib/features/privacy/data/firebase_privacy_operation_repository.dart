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
  Future<PrivacyOperation> request(PrivacyOperationStartCommand command) =>
      _invoke(
        name: 'preparePrivacyOperation',
        data: <String, Object>{
          'type': command.type.name,
          'confirmationPhrase': command.confirmationPhrase,
          'idempotencyKey': command.idempotencyKey.value,
        },
      );

  @override
  Future<PrivacyOperation> retry(PrivacyOperationId operationId) => _invoke(
    name: 'confirmPrivacyOperation',
    data: <String, Object>{'operationId': operationId.value},
  );

  @override
  Future<PrivacyOperation> status(PrivacyOperationId operationId) => _invoke(
    name: 'getPrivacyOperationStatus',
    data: <String, Object>{'operationId': operationId.value},
  );

  Future<PrivacyOperation> _invoke({
    required String name,
    required Map<String, Object> data,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw const PrivacyOperationFailure(
          PrivacyOperationFailureKind.unauthenticated,
        );
      }
      // A renovação ocorre após reautenticação. O backend ainda é a única
      // autoridade para validar auth_time, identidade e App Check.
      await user.getIdToken(true);
      final HttpsCallableResult<Object?> response = await _functions
          .httpsCallable(name)
          .call<Object?>(data);
      return _mapOperation(response.data, user.uid);
    } on PrivacyOperationFailure {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw PrivacyOperationFailure(_mapFailure(error.code));
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

  PrivacyOperation _mapOperation(Object? value, String ownerId) {
    if (value is! Map<Object?, Object?>) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    final Map<String, Object?> data = Map<String, Object?>.from(value);
    final String? id = data['operationId'] as String?;
    final String? type = data['type'] as String?;
    final String? state = data['state'] as String?;
    final int? revision = data['revision'] as int?;
    final DateTime? createdAt = _serverDate(data['createdAt']);
    final DateTime? updatedAt = _serverDate(data['updatedAt']);
    if (
      id == null || type == null || state == null || revision == null ||
      createdAt == null || updatedAt == null
    ) {
      throw const PrivacyOperationFailure(
        PrivacyOperationFailureKind.inconsistentState,
      );
    }
    return PrivacyOperation(
      id: PrivacyOperationId(id),
      type: PrivacyOperationType.values.byName(type),
      ownerId: ownerId,
      state: _stateFor(state),
      revision: revision,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  DateTime? _serverDate(Object? value) => switch (value) {
    final String value => DateTime.tryParse(value)?.toUtc(),
    final DateTime value => value.toUtc(),
    _ => null,
  };

  PrivacyOperationState _stateFor(String value) => switch (value) {
    'prepared' => PrivacyOperationState.prepared,
    'confirmed' => PrivacyOperationState.confirmed,
    'locked' => PrivacyOperationState.writeLocked,
    'deleting' => PrivacyOperationState.deletingFinancialData,
    'authDeletionPending' => PrivacyOperationState.authenticationDeletionPending,
    'failed' => PrivacyOperationState.retryableFailure,
    _ => throw const PrivacyOperationFailure(
      PrivacyOperationFailureKind.inconsistentState,
    ),
  };

  PrivacyOperationFailureKind _mapFailure(String code) => switch (code) {
    'unauthenticated' => PrivacyOperationFailureKind.unauthenticated,
    'permission-denied' => PrivacyOperationFailureKind.legalProfileRequired,
    'failed-precondition' =>
      PrivacyOperationFailureKind.recentAuthenticationRequired,
    'deadline-exceeded' => PrivacyOperationFailureKind.timeout,
    'invalid-argument' => PrivacyOperationFailureKind.invalidRequest,
    _ => PrivacyOperationFailureKind.unavailable,
  };
}
