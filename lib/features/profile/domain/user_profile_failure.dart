enum UserProfileFailureKind {
  permissionDenied,
  unauthenticated,
  unavailable,
  timeout,
  aborted,
  failedPrecondition,
  notFound,
  dataLoss,
  conversion,
  incompatible,
  network,
  authMirror,
  unknown,
}

final class UserProfileFailure implements Exception {
  const UserProfileFailure({
    required this.kind,
    required this.safeMessage,
    this.code,
  });

  final UserProfileFailureKind kind;
  final String safeMessage;
  final String? code;

  bool get isRecoverable => switch (kind) {
    UserProfileFailureKind.unavailable ||
    UserProfileFailureKind.timeout ||
    UserProfileFailureKind.aborted ||
    UserProfileFailureKind.network ||
    UserProfileFailureKind.authMirror => true,
    _ => false,
  };

  @override
  String toString() => 'UserProfileFailure(${kind.name})';
}
