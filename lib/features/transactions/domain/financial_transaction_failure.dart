enum FinancialTransactionFailureKind {
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
  accountArchived,
  categoryArchived,
  categoryMismatch,
  invalidAmount,
  futureDate,
  invalidDescription,
  invalidNotes,
  voided,
  uncertain,
  overflow,
  validation,
  unknown,
}

final class FinancialTransactionFailure implements Exception {
  const FinancialTransactionFailure({
    required this.kind,
    required this.safeMessage,
    this.code,
  });

  final FinancialTransactionFailureKind kind;
  final String safeMessage;
  final String? code;

  bool get isUncertain =>
      kind == FinancialTransactionFailureKind.unavailable ||
      kind == FinancialTransactionFailureKind.timeout ||
      kind == FinancialTransactionFailureKind.aborted ||
      kind == FinancialTransactionFailureKind.uncertain;

  @override
  String toString() => 'FinancialTransactionFailure(${kind.name})';
}
