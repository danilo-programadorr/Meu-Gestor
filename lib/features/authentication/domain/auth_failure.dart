enum AuthFailureKind {
  invalidCredentials,
  invalidEmail,
  weakPassword,
  accountCreation,
  missingCredential,
  network,
  googleClientConfiguration,
  googleAuthentication,
  firebaseAuthentication,
  tooManyRequests,
  operationNotAllowed,
  unknown,
}

final class AuthFailure implements Exception {
  const AuthFailure({required this.kind, required this.safeMessage});

  final AuthFailureKind kind;
  final String safeMessage;

  @override
  String toString() => 'AuthFailure(${kind.name})';
}

enum GoogleAuthOutcome { success, cancelled }
