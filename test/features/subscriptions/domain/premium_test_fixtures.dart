import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

final DateTime premiumStartedAt = DateTime.utc(2026, 8, 1);
final DateTime premiumPeriodStartedAt = DateTime.utc(2026, 8, 10);
final DateTime premiumPeriodEndsAt = DateTime.utc(2026, 9, 10);
final DateTime premiumLastVerifiedAt = DateTime.utc(2026, 8, 20);

PremiumEntitlement premiumEntitlement({
  PremiumEntitlementStatus status = PremiumEntitlementStatus.active,
  String ownerId = 'synthetic-owner',
  PremiumPlan plan = PremiumPlan.monthly,
  PremiumEntitlementSource source = PremiumEntitlementSource.googlePlay,
  PremiumEnvironment environment = PremiumEnvironment.development,
  Iterable<PremiumCapability>? capabilities,
  DateTime? entitlementStartedAt,
  DateTime? currentPeriodStartedAt,
  DateTime? currentPeriodEndsAt,
  DateTime? graceUntil,
  bool? cancelAtPeriodEnd,
  DateTime? cancelledAt,
  DateTime? expiredAt,
  DateTime? revokedAt,
  DateTime? refundedAt,
  DateTime? lastVerifiedAt,
  int revision = 1,
  int schemaVersion = PremiumEntitlement.currentSchemaVersion,
}) {
  final bool pending = status == PremiumEntitlementStatus.pending;
  final bool cancelled = status == PremiumEntitlementStatus.cancelled;
  final bool expired = status == PremiumEntitlementStatus.expired;
  final bool revoked = status == PremiumEntitlementStatus.revoked;
  final bool refunded = status == PremiumEntitlementStatus.refunded;
  return PremiumEntitlement.create(
    ownerId: ownerId,
    plan: plan,
    status: status,
    source: source,
    environment: environment,
    capabilities: capabilities ?? plan.includedCapabilities,
    entitlementStartedAt: pending
        ? entitlementStartedAt
        : entitlementStartedAt ?? premiumStartedAt,
    currentPeriodStartedAt: pending
        ? currentPeriodStartedAt
        : currentPeriodStartedAt ?? premiumPeriodStartedAt,
    currentPeriodEndsAt: pending
        ? currentPeriodEndsAt
        : currentPeriodEndsAt ?? premiumPeriodEndsAt,
    graceUntil: status == PremiumEntitlementStatus.gracePeriod
        ? graceUntil ?? DateTime.utc(2026, 9, 17)
        : graceUntil,
    cancelAtPeriodEnd: cancelAtPeriodEnd ?? cancelled,
    cancelledAt: cancelled
        ? cancelledAt ?? DateTime.utc(2026, 8, 15)
        : cancelledAt,
    expiredAt: expired ? expiredAt ?? premiumPeriodEndsAt : expiredAt,
    revokedAt: revoked ? revokedAt ?? DateTime.utc(2026, 8, 15) : revokedAt,
    refundedAt: refunded ? refundedAt ?? DateTime.utc(2026, 8, 15) : refundedAt,
    lastVerifiedAt:
        lastVerifiedAt ??
        (expired ? DateTime.utc(2026, 9, 11) : premiumLastVerifiedAt),
    revision: revision,
    schemaVersion: schemaVersion,
  );
}
