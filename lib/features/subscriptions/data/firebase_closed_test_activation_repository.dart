import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';

typedef ClosedTestActivationInvoker =
    Future<Object?> Function(Map<String, Object?> payload);

/// Borda estrita da callable de teste fechado. A resposta nunca concede
/// acesso por si só: o controller sempre relê o entitlement pelo servidor.
final class FirebaseClosedTestActivationRepository
    implements ClosedTestActivationRepository {
  FirebaseClosedTestActivationRepository({required FirebaseFunctions functions})
    : this.withInvoker(
        invoker: (Map<String, Object?> payload) async {
          final HttpsCallableResult<Object?> response = await functions
              .httpsCallable(callableName)
              .call<Object?>(payload);
          return response.data;
        },
      );

  @visibleForTesting
  FirebaseClosedTestActivationRepository.withInvoker({
    required ClosedTestActivationInvoker invoker,
    Duration timeout = const Duration(seconds: 18),
  }) : _invoker = invoker,
       _timeout = timeout;

  static const String callableName = 'activateClosedTestPremium';
  static const Set<String> _responseFields = <String>{
    'status',
    'revision',
    'requiresServerRefresh',
  };

  final ClosedTestActivationInvoker _invoker;
  final Duration _timeout;

  @override
  Future<void> activateCurrentUser() async {
    try {
      final Object? response = await _invoker(
        const <String, Object?>{},
      ).timeout(_timeout);
      _validateResponse(response);
    } on ClosedTestActivationFailure {
      rethrow;
    } on TimeoutException {
      throw const ClosedTestActivationFailure(
        kind: ClosedTestActivationFailureKind.timeout,
        safeMessage: 'A ativação do acesso Premium demorou demais.',
        code: 'closed_test_activation_timeout',
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFirebaseFailure(error.code);
    } on Object {
      throw const ClosedTestActivationFailure(
        kind: ClosedTestActivationFailureKind.unknown,
        safeMessage: 'Não foi possível confirmar o acesso ao teste fechado.',
        code: 'closed_test_activation_unknown',
      );
    }
  }

  static void _validateResponse(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const ClosedTestActivationFailure(
        kind: ClosedTestActivationFailureKind.invalidResponse,
        safeMessage: 'O servidor retornou uma confirmação incompatível.',
        code: 'closed_test_activation_invalid_response',
      );
    }
    final Map<String, Object?> response;
    try {
      response = Map<String, Object?>.from(value);
    } on Object {
      throw const ClosedTestActivationFailure(
        kind: ClosedTestActivationFailureKind.invalidResponse,
        safeMessage: 'O servidor retornou uma confirmação incompatível.',
        code: 'closed_test_activation_invalid_response',
      );
    }
    if (!setEquals(response.keys.toSet(), _responseFields) ||
        response['status'] != 'active' ||
        response['revision'] is! int ||
        (response['revision']! as int) < 1 ||
        response['requiresServerRefresh'] != true) {
      throw const ClosedTestActivationFailure(
        kind: ClosedTestActivationFailureKind.invalidResponse,
        safeMessage: 'O servidor retornou uma confirmação incompatível.',
        code: 'closed_test_activation_invalid_response',
      );
    }
  }

  static ClosedTestActivationFailure _mapFirebaseFailure(String code) =>
      switch (code) {
        'permission-denied' => const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.notAuthorized,
          safeMessage: 'O acesso ao teste fechado não está disponível.',
          code: 'closed_test_not_authorized',
        ),
        'failed-precondition' => const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.appCheckRejected,
          safeMessage:
              'Não foi possível validar esta instalação do aplicativo.',
          code: 'closed_test_app_check_rejected',
        ),
        'deadline-exceeded' => const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.timeout,
          safeMessage: 'A ativação do acesso Premium demorou demais.',
          code: 'closed_test_activation_deadline',
        ),
        'unavailable' => const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.unavailable,
          safeMessage: 'A ativação do teste fechado está indisponível.',
          code: 'closed_test_activation_unavailable',
        ),
        _ => const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.unknown,
          safeMessage: 'Não foi possível confirmar o acesso ao teste fechado.',
          code: 'closed_test_activation_functions_error',
        ),
      };
}
