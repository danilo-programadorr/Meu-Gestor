enum ClosedTestActivationFailureKind {
  notAuthorized,
  appCheckRejected,
  timeout,
  unavailable,
  invalidResponse,
  unknown,
}

final class ClosedTestActivationFailure implements Exception {
  const ClosedTestActivationFailure({
    required this.kind,
    required this.safeMessage,
    required this.code,
  });

  final ClosedTestActivationFailureKind kind;
  final String safeMessage;
  final String code;

  @override
  String toString() => 'ClosedTestActivationFailure($code)';
}

abstract interface class ClosedTestActivationRepository {
  /// Solicita a ativação do próprio chamador. O contrato não aceita UID,
  /// ambiente, duração, track ou capabilities enviados pelo aplicativo.
  Future<void> activateCurrentUser();
}
