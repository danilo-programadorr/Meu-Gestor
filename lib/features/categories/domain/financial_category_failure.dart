enum FinancialCategoryFailureKind {
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
  archived,
  validation,
  unknown,
}

final class FinancialCategoryFailure implements Exception {
  const FinancialCategoryFailure({
    required this.kind,
    required this.safeMessage,
    this.code,
  });

  final FinancialCategoryFailureKind kind;
  final String safeMessage;
  final String? code;

  bool get isUncertain =>
      kind == FinancialCategoryFailureKind.unavailable ||
      kind == FinancialCategoryFailureKind.timeout ||
      kind == FinancialCategoryFailureKind.aborted;

  @override
  String toString() => 'FinancialCategoryFailure(${kind.name})';
}
