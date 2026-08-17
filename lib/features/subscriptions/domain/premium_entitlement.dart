import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

final class PremiumEntitlement {
  PremiumEntitlement._({
    required this.ownerId,
    required this.plan,
    required this.status,
    required this.source,
    required this.environment,
    required Set<PremiumCapability> capabilities,
    required this.entitlementStartedAt,
    required this.currentPeriodStartedAt,
    required this.currentPeriodEndsAt,
    required this.graceUntil,
    required this.cancelAtPeriodEnd,
    required this.cancelledAt,
    required this.expiredAt,
    required this.revokedAt,
    required this.refundedAt,
    required this.lastVerifiedAt,
    required this.revision,
    required this.schemaVersion,
  }) : capabilities = Set<PremiumCapability>.unmodifiable(capabilities);

  factory PremiumEntitlement.create({
    required String ownerId,
    required PremiumPlan plan,
    required PremiumEntitlementStatus status,
    required PremiumEntitlementSource source,
    required PremiumEnvironment environment,
    required Iterable<PremiumCapability> capabilities,
    required DateTime? entitlementStartedAt,
    required DateTime? currentPeriodStartedAt,
    required DateTime? currentPeriodEndsAt,
    required DateTime? graceUntil,
    required bool cancelAtPeriodEnd,
    required DateTime? cancelledAt,
    required DateTime? expiredAt,
    required DateTime? revokedAt,
    required DateTime? refundedAt,
    required DateTime lastVerifiedAt,
    required int revision,
    required int schemaVersion,
  }) {
    final List<PremiumCapability> capabilityList = capabilities.toList();
    final Set<PremiumCapability> capabilitySet = capabilityList.toSet();
    _validate(
      ownerId: ownerId,
      plan: plan,
      status: status,
      source: source,
      environment: environment,
      capabilityCount: capabilityList.length,
      uniqueCapabilityCount: capabilitySet.length,
      capabilities: capabilitySet,
      entitlementStartedAt: entitlementStartedAt,
      currentPeriodStartedAt: currentPeriodStartedAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      graceUntil: graceUntil,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      cancelledAt: cancelledAt,
      expiredAt: expiredAt,
      revokedAt: revokedAt,
      refundedAt: refundedAt,
      lastVerifiedAt: lastVerifiedAt,
      revision: revision,
      schemaVersion: schemaVersion,
    );
    return PremiumEntitlement._(
      ownerId: ownerId,
      plan: plan,
      status: status,
      source: source,
      environment: environment,
      capabilities: capabilitySet,
      entitlementStartedAt: entitlementStartedAt,
      currentPeriodStartedAt: currentPeriodStartedAt,
      currentPeriodEndsAt: currentPeriodEndsAt,
      graceUntil: graceUntil,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      cancelledAt: cancelledAt,
      expiredAt: expiredAt,
      revokedAt: revokedAt,
      refundedAt: refundedAt,
      lastVerifiedAt: lastVerifiedAt,
      revision: revision,
      schemaVersion: schemaVersion,
    );
  }

  static const int currentSchemaVersion = 1;

  final String ownerId;
  final PremiumPlan plan;
  final PremiumEntitlementStatus status;
  final PremiumEntitlementSource source;
  final PremiumEnvironment environment;
  final Set<PremiumCapability> capabilities;
  final DateTime? entitlementStartedAt;
  final DateTime? currentPeriodStartedAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? graceUntil;
  final bool cancelAtPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;
  final DateTime? revokedAt;
  final DateTime? refundedAt;
  final DateTime lastVerifiedAt;
  final int revision;
  final int schemaVersion;

  DateTime? get accessEndsAt => switch (status) {
    PremiumEntitlementStatus.gracePeriod => graceUntil,
    PremiumEntitlementStatus.trialing ||
    PremiumEntitlementStatus.active ||
    PremiumEntitlementStatus.cancelled => currentPeriodEndsAt,
    _ => null,
  };

  static void _validate({
    required String ownerId,
    required PremiumPlan plan,
    required PremiumEntitlementStatus status,
    required PremiumEntitlementSource source,
    required PremiumEnvironment environment,
    required int capabilityCount,
    required int uniqueCapabilityCount,
    required Set<PremiumCapability> capabilities,
    required DateTime? entitlementStartedAt,
    required DateTime? currentPeriodStartedAt,
    required DateTime? currentPeriodEndsAt,
    required DateTime? graceUntil,
    required bool cancelAtPeriodEnd,
    required DateTime? cancelledAt,
    required DateTime? expiredAt,
    required DateTime? revokedAt,
    required DateTime? refundedAt,
    required DateTime lastVerifiedAt,
    required int revision,
    required int schemaVersion,
  }) {
    if (ownerId.trim().isEmpty || ownerId != ownerId.trim()) {
      throw _inconsistent('invalid_premium_owner');
    }
    if (!plan.isPremium) {
      throw _inconsistent('free_plan_has_no_entitlement');
    }
    if (schemaVersion != currentSchemaVersion) {
      throw const PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.incompatibleSchema,
        safeMessage: 'A versão do acesso Premium não é compatível.',
        code: 'incompatible_premium_schema',
      );
    }
    if (revision < 1) {
      throw _inconsistent('invalid_premium_revision');
    }
    if (capabilityCount != uniqueCapabilityCount) {
      throw _inconsistent('duplicated_premium_capability');
    }
    if (!_isUtc(lastVerifiedAt) ||
        !_allUtc(<DateTime?>[
          entitlementStartedAt,
          currentPeriodStartedAt,
          currentPeriodEndsAt,
          graceUntil,
          cancelledAt,
          expiredAt,
          revokedAt,
          refundedAt,
        ])) {
      throw _period('premium_dates_must_be_utc');
    }

    final bool hasAnyPeriodDate =
        entitlementStartedAt != null ||
        currentPeriodStartedAt != null ||
        currentPeriodEndsAt != null;
    final bool hasCompletePeriod =
        entitlementStartedAt != null &&
        currentPeriodStartedAt != null &&
        currentPeriodEndsAt != null;
    if (hasAnyPeriodDate != hasCompletePeriod) {
      throw _period('incomplete_premium_period');
    }
    if (hasCompletePeriod) {
      if (!entitlementStartedAt.isBefore(currentPeriodEndsAt) ||
          currentPeriodStartedAt.isBefore(entitlementStartedAt) ||
          !currentPeriodStartedAt.isBefore(currentPeriodEndsAt)) {
        throw _period('invalid_premium_period');
      }
      if (lastVerifiedAt.isBefore(entitlementStartedAt)) {
        throw _period('verification_before_entitlement');
      }
    }

    final bool requiresPeriod = status != PremiumEntitlementStatus.pending;
    if (requiresPeriod && !hasCompletePeriod) {
      throw _state('premium_state_requires_period');
    }
    if (status == PremiumEntitlementStatus.pending && hasAnyPeriodDate) {
      throw _state('pending_with_period');
    }
    if (status == PremiumEntitlementStatus.pending &&
        source != PremiumEntitlementSource.googlePlay) {
      throw _state('grant_cannot_be_pending');
    }
    if (source == PremiumEntitlementSource.developmentGrant &&
        environment != PremiumEnvironment.development) {
      throw _state('development_grant_wrong_environment');
    }
    if (source == PremiumEntitlementSource.closedTestGrant &&
        environment != PremiumEnvironment.development) {
      throw _state('closed_test_grant_wrong_environment');
    }
    if (source == PremiumEntitlementSource.closedTestGrant) {
      final Set<PremiumCapability> fullPremiumCapabilities =
          PremiumPlan.monthly.includedCapabilities;
      final bool hasExactlyFullPremiumCapabilities =
          capabilities.length == fullPremiumCapabilities.length &&
          capabilities.containsAll(fullPremiumCapabilities);
      if (status == PremiumEntitlementStatus.active &&
          !hasExactlyFullPremiumCapabilities) {
        throw _state('closed_test_grant_requires_full_capabilities');
      }
      if (status == PremiumEntitlementStatus.expired &&
          capabilities.isNotEmpty) {
        throw _state('expired_closed_test_grant_keeps_no_capabilities');
      }
      if (status != PremiumEntitlementStatus.active &&
          status != PremiumEntitlementStatus.expired) {
        throw _state('invalid_closed_test_grant_status');
      }
    }

    if ((status == PremiumEntitlementStatus.gracePeriod) !=
        (graceUntil != null)) {
      throw _state('invalid_grace_date');
    }
    if (graceUntil != null && !currentPeriodEndsAt!.isBefore(graceUntil)) {
      throw _period('grace_must_extend_period');
    }

    final bool cancellationFieldsMatch =
        cancelAtPeriodEnd == (cancelledAt != null);
    if (!cancellationFieldsMatch ||
        (cancelAtPeriodEnd &&
            status != PremiumEntitlementStatus.cancelled &&
            status != PremiumEntitlementStatus.expired)) {
      throw _state('invalid_cancellation_fields');
    }
    if (status == PremiumEntitlementStatus.cancelled && !cancelAtPeriodEnd) {
      throw _state('cancelled_without_scheduled_end');
    }
    if (cancelledAt != null &&
        (cancelledAt.isBefore(entitlementStartedAt!) ||
            cancelledAt.isAfter(lastVerifiedAt))) {
      throw _period('invalid_cancellation_date');
    }

    _validateExclusiveStateDate(
      status: status,
      expectedStatus: PremiumEntitlementStatus.expired,
      date: expiredAt,
      code: 'invalid_expiration_date',
    );
    _validateExclusiveStateDate(
      status: status,
      expectedStatus: PremiumEntitlementStatus.revoked,
      date: revokedAt,
      code: 'invalid_revocation_date',
    );
    _validateExclusiveStateDate(
      status: status,
      expectedStatus: PremiumEntitlementStatus.refunded,
      date: refundedAt,
      code: 'invalid_refund_date',
    );
    if (expiredAt != null &&
        (expiredAt.isBefore(currentPeriodEndsAt!) ||
            expiredAt.isAfter(lastVerifiedAt))) {
      throw _period('invalid_expiration_order');
    }
    for (final DateTime? immediateDate in <DateTime?>[revokedAt, refundedAt]) {
      if (immediateDate != null &&
          (immediateDate.isBefore(entitlementStartedAt!) ||
              immediateDate.isAfter(lastVerifiedAt))) {
        throw _period('invalid_terminal_date_order');
      }
    }
  }

  static void _validateExclusiveStateDate({
    required PremiumEntitlementStatus status,
    required PremiumEntitlementStatus expectedStatus,
    required DateTime? date,
    required String code,
  }) {
    if ((status == expectedStatus) != (date != null)) {
      throw _state(code);
    }
  }

  static bool _isUtc(DateTime value) => value.isUtc;

  static bool _allUtc(Iterable<DateTime?> values) =>
      values.whereType<DateTime>().every(_isUtc);

  static PremiumEntitlementFailure _state(String code) =>
      PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.invalidState,
        safeMessage: 'O estado do acesso Premium é inconsistente.',
        code: code,
      );

  static PremiumEntitlementFailure _period(String code) =>
      PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.invalidPeriod,
        safeMessage: 'O período do acesso Premium é inconsistente.',
        code: code,
      );

  static PremiumEntitlementFailure _inconsistent(String code) =>
      PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.inconsistentData,
        safeMessage: 'Os dados do acesso Premium são inconsistentes.',
        code: code,
      );
}
