import 'dart:async';

import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

final class FakePremiumEntitlementRepository
    implements PremiumEntitlementRepository {
  FakePremiumEntitlementRepository({this.entitlement});

  PremiumEntitlement? entitlement;
  Object? nextFailure;
  Completer<void>? readBarrier;
  bool isFromServer = true;
  bool hasPendingWrites = false;
  int refreshCalls = 0;

  PremiumEntitlementReadResult get _result => entitlement == null
      ? PremiumEntitlementReadResult.absent(
          isFromServer: isFromServer,
          hasPendingWrites: hasPendingWrites,
        )
      : PremiumEntitlementReadResult.present(
          entitlement: entitlement!,
          isFromServer: isFromServer,
          hasPendingWrites: hasPendingWrites,
        );

  @override
  Future<PremiumEntitlementReadResult> readCurrent({
    required String ownerId,
    required bool serverOnly,
  }) => _read(ownerId);

  @override
  Future<PremiumEntitlementReadResult> refreshFromServer({
    required String ownerId,
  }) async {
    refreshCalls += 1;
    return _read(ownerId);
  }

  Future<PremiumEntitlementReadResult> _read(String ownerId) async {
    await readBarrier?.future;
    final Object? failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    final PremiumEntitlement? current = entitlement;
    if (current != null && current.ownerId != ownerId) {
      throw StateError('synthetic owner mismatch');
    }
    return _result;
  }

  @override
  Stream<PremiumEntitlementReadResult> watchConfirmed({
    required String ownerId,
  }) => Stream<PremiumEntitlementReadResult>.value(_result);

  @override
  Future<PremiumEntitlementDiagnostic> readSanitizedDiagnostic({
    required String ownerId,
  }) async => PremiumEntitlementDiagnostic(
    code: entitlement == null ? 'premium_absent' : 'premium_present',
    isFromServer: isFromServer,
    schemaVersion: entitlement?.schemaVersion,
    revision: entitlement?.revision,
  );
}

PremiumEntitlement syntheticPremiumEntitlement({
  String ownerId = 'owner',
  PremiumEntitlementStatus status = PremiumEntitlementStatus.active,
  Iterable<PremiumCapability> capabilities = const <PremiumCapability>{
    PremiumCapability.investmentsManual,
    PremiumCapability.investmentIncome,
  },
  PremiumEnvironment environment = PremiumEnvironment.development,
  DateTime? currentPeriodEndsAt,
}) {
  final DateTime startedAt = DateTime.utc(2026, 8, 1);
  final DateTime periodStart = DateTime.utc(2026, 8, 2);
  final DateTime periodEnd = currentPeriodEndsAt ?? DateTime.utc(2026, 9, 10);
  final bool pending = status == PremiumEntitlementStatus.pending;
  final bool cancelled = status == PremiumEntitlementStatus.cancelled;
  final bool expired = status == PremiumEntitlementStatus.expired;
  final bool revoked = status == PremiumEntitlementStatus.revoked;
  final bool refunded = status == PremiumEntitlementStatus.refunded;
  return PremiumEntitlement.create(
    ownerId: ownerId,
    plan: PremiumPlan.monthly,
    status: status,
    source: PremiumEntitlementSource.googlePlay,
    environment: environment,
    capabilities: capabilities,
    entitlementStartedAt: pending ? null : startedAt,
    currentPeriodStartedAt: pending ? null : periodStart,
    currentPeriodEndsAt: pending ? null : periodEnd,
    graceUntil: status == PremiumEntitlementStatus.gracePeriod
        ? DateTime.utc(2026, 9, 17)
        : null,
    cancelAtPeriodEnd: cancelled,
    cancelledAt: cancelled ? DateTime.utc(2026, 8, 5) : null,
    expiredAt: expired ? periodEnd : null,
    revokedAt: revoked ? DateTime.utc(2026, 8, 5) : null,
    refundedAt: refunded ? DateTime.utc(2026, 8, 5) : null,
    lastVerifiedAt: expired
        ? periodEnd.add(const Duration(hours: 1))
        : DateTime.utc(2026, 8, 10),
    revision: 1,
    schemaVersion: PremiumEntitlement.currentSchemaVersion,
  );
}
