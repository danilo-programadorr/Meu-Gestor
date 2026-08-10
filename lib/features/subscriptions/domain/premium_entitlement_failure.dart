enum PremiumEntitlementFailureKind {
  missingEntitlement,
  incompatibleSchema,
  invalidState,
  invalidPeriod,
  capabilityNotGranted,
  expired,
  revoked,
  refunded,
  serverConfirmationUnavailable,
  inconsistentData,
  unauthenticated,
  permissionDenied,
  unavailable,
  unknown,
}

final class PremiumEntitlementFailure implements Exception {
  const PremiumEntitlementFailure({
    required this.kind,
    required this.safeMessage,
    required this.code,
  });

  final PremiumEntitlementFailureKind kind;
  final String safeMessage;
  final String code;

  @override
  String toString() => 'PremiumEntitlementFailure($code)';
}
