import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_integration.dart';

typedef AssistantRemoteCallableInvoker =
    Future<Object?> Function(Map<String, Object?> data);

/// Cliente estrito da callable `assistRemoteV1`.
///
/// O flag compilado permanece desligado. Nesse estado [ask] retorna a
/// indisponibilidade local sem instanciar uma chamada de rede e sem montar
/// contexto, identidade, valores, modelo ou qualquer outro campo.
final class FirebaseAssistantRemoteGateway implements AssistantRemoteGateway {
  FirebaseAssistantRemoteGateway({required FirebaseFunctions functions})
    : this.withInvoker(
        invoker: (Map<String, Object?> data) async {
          final HttpsCallableResult<Object?> result = await functions
              .httpsCallable(callableName)
              .call<Object?>(data);
          return result.data;
        },
      );

  @visibleForTesting
  FirebaseAssistantRemoteGateway.withInvoker({
    required AssistantRemoteCallableInvoker invoker,
    Duration timeout = const Duration(seconds: 18),
  }) : _invoker = invoker,
       _timeout = timeout;

  static const String callableName = 'assistRemoteV1';

  final AssistantRemoteCallableInvoker _invoker;
  final Duration _timeout;

  @override
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request) async {
    if (!AssistantRemoteIntegrationPolicy.realCallsEnabled) {
      return AssistantRemoteResponse.safeUnavailable;
    }

    try {
      final Object? response = await _invoker(
        _payloadFor(request),
      ).timeout(_timeout);
      return AssistantRemoteResponse.fromCallableData(response);
    } on AssistantFailure {
      rethrow;
    } on TimeoutException {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    } on FirebaseFunctionsException {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    } on Object {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    }
  }

  /// Mantido separado para que a forma exata do contrato seja verificável sem
  /// habilitar rede em testes ou builds Flutter.
  @visibleForTesting
  static Map<String, Object?> payloadFor(AssistantRemoteRequest request) =>
      _payloadFor(request);

  static Map<String, Object?> _payloadFor(AssistantRemoteRequest request) =>
      <String, Object?>{
        'contractVersion': AssistantRemoteRequest.contractVersion,
        'message': request.message,
      };
}
