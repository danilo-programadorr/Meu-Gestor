enum MasterAccessFailureKind {
  permissionDenied,
  unauthenticated,
  unavailable,
  timeout,
  notFound,
  dataLoss,
  conversion,
  incompatible,
  failedPrecondition,
  unknown,
}

final class MasterAccessFailure implements Exception {
  const MasterAccessFailure({
    required this.kind,
    required this.safeMessage,
    required this.code,
  });

  final MasterAccessFailureKind kind;
  final String safeMessage;
  final String code;

  @override
  String toString() => 'MasterAccessFailure($kind, $code)';
}
