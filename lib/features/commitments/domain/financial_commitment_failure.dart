enum FinancialCommitmentFailureKind {
  validation,
  invalidAmount,
  invalidDescription,
  invalidNotes,
  invalidDate,
  invalidState,
  incompatible,
  notFound,
  alreadyExists,
  conflict,
  unauthenticated,
  permissionDenied,
  unavailable,
  timeout,
  dataLoss,
  failedPrecondition,
  unknown,
}

final class FinancialCommitmentFailure implements Exception {
  const FinancialCommitmentFailure({
    required this.kind,
    required this.safeMessage,
    required this.code,
  });

  final FinancialCommitmentFailureKind kind;
  final String safeMessage;
  final String code;

  @override
  String toString() => 'FinancialCommitmentFailure($code)';
}
