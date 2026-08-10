enum InvestmentFailureKind {
  permissionDenied,
  unauthenticated,
  unavailable,
  timeout,
  aborted,
  failedPrecondition,
  notFound,
  alreadyExists,
  incompatible,
  validation,
  insufficientPosition,
  chronologicalOrder,
  historicalCorrectionBlocked,
  overflow,
  unknown,
}

final class InvestmentFailure implements Exception {
  const InvestmentFailure({
    required this.kind,
    required this.safeMessage,
    this.code,
  });

  final InvestmentFailureKind kind;
  final String safeMessage;
  final String? code;

  bool get isUncertain =>
      kind == InvestmentFailureKind.unavailable ||
      kind == InvestmentFailureKind.timeout ||
      kind == InvestmentFailureKind.aborted;

  @override
  String toString() => 'InvestmentFailure(${kind.name})';
}
