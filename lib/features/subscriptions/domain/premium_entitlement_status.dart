enum PremiumEntitlementStatus {
  pending,
  trialing,
  active,
  gracePeriod,
  accountHold,
  paused,
  cancelled,
  expired,
  revoked,
  refunded,
}

extension PremiumEntitlementStatusProperties on PremiumEntitlementStatus {
  bool get grantsTimedAccess =>
      this == PremiumEntitlementStatus.trialing ||
      this == PremiumEntitlementStatus.active ||
      this == PremiumEntitlementStatus.gracePeriod ||
      this == PremiumEntitlementStatus.cancelled;

  bool get isTerminal =>
      this == PremiumEntitlementStatus.revoked ||
      this == PremiumEntitlementStatus.refunded;
}
