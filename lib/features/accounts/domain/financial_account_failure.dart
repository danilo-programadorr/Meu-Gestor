enum FinancialAccountFailureKind {
  permissionDenied,
  unauthenticated,
  unavailable,
  timeout,
  aborted,
  failedPrecondition,
  notFound,
  alreadyExists,
  dataLoss,
  conversion,
  incompatible,
  validation,
  unknown,
}

final class FinancialAccountFailure implements Exception {
  const FinancialAccountFailure({
    required this.kind,
    required this.safeMessage,
    this.code,
  });

  final FinancialAccountFailureKind kind;
  final String safeMessage;
  final String? code;

  bool get isUncertain =>
      kind == FinancialAccountFailureKind.unavailable ||
      kind == FinancialAccountFailureKind.timeout ||
      kind == FinancialAccountFailureKind.aborted;

  @override
  String toString() => 'FinancialAccountFailure(${kind.name})';
}
