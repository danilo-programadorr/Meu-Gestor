import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_access_decision.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';

final class PremiumEntitlementPolicy {
  const PremiumEntitlementPolicy({
    required this.environment,
    this.maximumVerificationAge,
  });

  final PremiumEnvironment environment;
  final Duration? maximumVerificationAge;

  PremiumAccessDecision decide({
    required PremiumEntitlement? entitlement,
    required PremiumCapability capability,
    required PremiumAccessIntent intent,
    required DateTime referenceInstant,
  }) {
    if (!referenceInstant.isUtc) {
      throw ArgumentError.value(
        referenceInstant,
        'referenceInstant',
        'O instante confiável deve estar em UTC.',
      );
    }
    final Duration? age = maximumVerificationAge;
    if (age != null && age <= Duration.zero) {
      throw ArgumentError.value(
        age,
        'maximumVerificationAge',
        'A validade da verificação deve ser positiva.',
      );
    }
    if (entitlement == null) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.missingEntitlement,
        allowRetainedRead: false,
      );
    }

    final bool stale =
        age != null &&
        referenceInstant.isAfter(entitlement.lastVerifiedAt.add(age));
    if (entitlement.environment != environment) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.environmentMismatch,
        requiresServerVerification: true,
        allowRetainedRead: false,
      );
    }
    // A concessão de teste fechado só é emitida/expirada pelo backend. O
    // aplicativo não usa o relógio do aparelho para antecipar ou prolongar a
    // janela; ele confia apenas no documento confirmado pelo servidor.
    if (entitlement.source == PremiumEntitlementSource.closedTestGrant) {
      if (entitlement.status != PremiumEntitlementStatus.active) {
        return _withoutFullAccess(
          capability: capability,
          intent: intent,
          reason: PremiumAccessReason.expired,
          allowRetainedRead: true,
        );
      }
      return PremiumAccessDecision(
        mode: PremiumAccessMode.full,
        reason: PremiumAccessReason.active,
        capability: capability,
        intent: intent,
        validUntil: entitlement.currentPeriodEndsAt,
        isGracePeriod: false,
        isCancellationPending: false,
        requiresServerVerification: false,
      );
    }

    if (!entitlement.capabilities.contains(capability)) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.capabilityNotGranted,
        requiresServerVerification: stale,
        allowRetainedRead: false,
      );
    }
    if (entitlement.status == PremiumEntitlementStatus.revoked) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.revoked,
      );
    }
    if (entitlement.status == PremiumEntitlementStatus.refunded) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.refunded,
      );
    }

    final DateTime? startsAt = entitlement.currentPeriodStartedAt;
    if (startsAt != null && referenceInstant.isBefore(startsAt)) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.notYetValid,
        requiresServerVerification: stale,
        allowRetainedRead: false,
      );
    }

    switch (entitlement.status) {
      case PremiumEntitlementStatus.pending:
        return _withoutFullAccess(
          capability: capability,
          intent: intent,
          reason: PremiumAccessReason.pendingServerConfirmation,
          requiresServerVerification: true,
          allowRetainedRead: false,
        );
      case PremiumEntitlementStatus.trialing:
        return _timedDecision(
          entitlement: entitlement,
          capability: capability,
          intent: intent,
          referenceInstant: referenceInstant,
          reason: PremiumAccessReason.trialing,
          stale: stale,
        );
      case PremiumEntitlementStatus.active:
        return _timedDecision(
          entitlement: entitlement,
          capability: capability,
          intent: intent,
          referenceInstant: referenceInstant,
          reason: PremiumAccessReason.active,
          stale: stale,
        );
      case PremiumEntitlementStatus.gracePeriod:
        return _timedDecision(
          entitlement: entitlement,
          capability: capability,
          intent: intent,
          referenceInstant: referenceInstant,
          reason: PremiumAccessReason.gracePeriod,
          stale: true,
          isGracePeriod: true,
        );
      case PremiumEntitlementStatus.cancelled:
        return _timedDecision(
          entitlement: entitlement,
          capability: capability,
          intent: intent,
          referenceInstant: referenceInstant,
          reason: PremiumAccessReason.cancelledUntilPeriodEnd,
          stale: stale,
          isCancellationPending: true,
        );
      case PremiumEntitlementStatus.accountHold:
        return _withoutFullAccess(
          capability: capability,
          intent: intent,
          reason: PremiumAccessReason.accountHold,
          requiresServerVerification: true,
        );
      case PremiumEntitlementStatus.paused:
        return _withoutFullAccess(
          capability: capability,
          intent: intent,
          reason: PremiumAccessReason.paused,
          requiresServerVerification: true,
        );
      case PremiumEntitlementStatus.expired:
        return _withoutFullAccess(
          capability: capability,
          intent: intent,
          reason: PremiumAccessReason.expired,
        );
      case PremiumEntitlementStatus.revoked:
      case PremiumEntitlementStatus.refunded:
        throw StateError('Estado terminal tratado antes do switch.');
    }
  }

  PremiumAccessDecision _timedDecision({
    required PremiumEntitlement entitlement,
    required PremiumCapability capability,
    required PremiumAccessIntent intent,
    required DateTime referenceInstant,
    required PremiumAccessReason reason,
    required bool stale,
    bool isGracePeriod = false,
    bool isCancellationPending = false,
  }) {
    final DateTime validUntil = entitlement.accessEndsAt!;
    if (!referenceInstant.isBefore(validUntil)) {
      return _withoutFullAccess(
        capability: capability,
        intent: intent,
        reason: PremiumAccessReason.expired,
        requiresServerVerification: stale,
      );
    }
    return PremiumAccessDecision(
      mode: PremiumAccessMode.full,
      reason: reason,
      capability: capability,
      intent: intent,
      validUntil: validUntil,
      isGracePeriod: isGracePeriod,
      isCancellationPending: isCancellationPending,
      requiresServerVerification: stale,
    );
  }

  PremiumAccessDecision _withoutFullAccess({
    required PremiumCapability capability,
    required PremiumAccessIntent intent,
    required PremiumAccessReason reason,
    bool requiresServerVerification = false,
    bool allowRetainedRead = true,
  }) {
    final bool canReadRetainedData =
        allowRetainedRead &&
        intent == PremiumAccessIntent.read &&
        capability.preservesUserData;
    return PremiumAccessDecision(
      mode: canReadRetainedData
          ? PremiumAccessMode.readOnly
          : PremiumAccessMode.denied,
      reason: canReadRetainedData
          ? PremiumAccessReason.retainedDataReadOnly
          : reason,
      capability: capability,
      intent: intent,
      validUntil: null,
      isGracePeriod: false,
      isCancellationPending: false,
      requiresServerVerification: requiresServerVerification,
    );
  }
}

enum PremiumTransitionReason {
  lifecycleProgression,
  renewal,
  newSubscription,
  staleRevision,
  repeatedRevision,
  ownerMismatch,
  environmentMismatch,
  sourceMismatch,
  terminalState,
  unsupportedTransition,
  periodRegression,
  verificationRegression,
}

final class PremiumTransitionDecision {
  const PremiumTransitionDecision({
    required this.isAllowed,
    required this.reason,
  });

  final bool isAllowed;
  final PremiumTransitionReason reason;
}

final class PremiumEntitlementTransitionPolicy {
  const PremiumEntitlementTransitionPolicy();

  PremiumTransitionDecision decide({
    required PremiumEntitlement current,
    required PremiumEntitlement next,
  }) {
    if (next.revision < current.revision) {
      return _deny(PremiumTransitionReason.staleRevision);
    }
    if (next.revision == current.revision) {
      return _deny(PremiumTransitionReason.repeatedRevision);
    }
    if (next.ownerId != current.ownerId) {
      return _deny(PremiumTransitionReason.ownerMismatch);
    }
    if (next.environment != current.environment) {
      return _deny(PremiumTransitionReason.environmentMismatch);
    }
    if (current.status.isTerminal) {
      return _deny(PremiumTransitionReason.terminalState);
    }
    final bool startsNewSubscription =
        current.status == PremiumEntitlementStatus.expired &&
        (next.status == PremiumEntitlementStatus.active ||
            next.status == PremiumEntitlementStatus.trialing);
    if (next.source != current.source && !startsNewSubscription) {
      return _deny(PremiumTransitionReason.sourceMismatch);
    }
    if (next.lastVerifiedAt.isBefore(current.lastVerifiedAt)) {
      return _deny(PremiumTransitionReason.verificationRegression);
    }
    if (!_allowedTargets(current.status).contains(next.status)) {
      return _deny(PremiumTransitionReason.unsupportedTransition);
    }

    final DateTime? currentEnd = current.currentPeriodEndsAt;
    final DateTime? nextEnd = next.currentPeriodEndsAt;
    final DateTime? currentStart = current.currentPeriodStartedAt;
    final DateTime? nextStart = next.currentPeriodStartedAt;
    if (currentEnd != null &&
        nextEnd != null &&
        nextEnd.isBefore(currentEnd) &&
        next.status != PremiumEntitlementStatus.revoked &&
        next.status != PremiumEntitlementStatus.refunded) {
      return _deny(PremiumTransitionReason.periodRegression);
    }
    if (!startsNewSubscription &&
        currentStart != null &&
        nextStart != null &&
        nextStart.isBefore(currentStart)) {
      return _deny(PremiumTransitionReason.periodRegression);
    }

    if (startsNewSubscription) {
      final DateTime newPeriodStart = next.currentPeriodStartedAt!;
      final DateTime endedAt = current.expiredAt!;
      if (newPeriodStart.isBefore(endedAt)) {
        return _deny(PremiumTransitionReason.periodRegression);
      }
      return _allow(PremiumTransitionReason.newSubscription);
    }

    if (current.status == next.status) {
      if (nextEnd == null ||
          currentEnd == null ||
          !nextEnd.isAfter(currentEnd)) {
        return _deny(PremiumTransitionReason.periodRegression);
      }
      return _allow(PremiumTransitionReason.renewal);
    }

    if (next.status == PremiumEntitlementStatus.active &&
        currentEnd != null &&
        nextEnd != null &&
        nextEnd.isAfter(currentEnd)) {
      return _allow(PremiumTransitionReason.renewal);
    }
    return _allow(PremiumTransitionReason.lifecycleProgression);
  }

  Set<PremiumEntitlementStatus> _allowedTargets(
    PremiumEntitlementStatus status,
  ) => switch (status) {
    PremiumEntitlementStatus.pending => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.trialing,
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.revoked,
    },
    PremiumEntitlementStatus.trialing => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.gracePeriod,
      PremiumEntitlementStatus.accountHold,
      PremiumEntitlementStatus.paused,
      PremiumEntitlementStatus.cancelled,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
    },
    PremiumEntitlementStatus.active => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.gracePeriod,
      PremiumEntitlementStatus.accountHold,
      PremiumEntitlementStatus.paused,
      PremiumEntitlementStatus.cancelled,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.gracePeriod => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.gracePeriod,
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.accountHold,
      PremiumEntitlementStatus.cancelled,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.accountHold => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.paused,
      PremiumEntitlementStatus.cancelled,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.paused => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.cancelled,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.cancelled => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.gracePeriod,
      PremiumEntitlementStatus.accountHold,
      PremiumEntitlementStatus.paused,
      PremiumEntitlementStatus.expired,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.expired => const <PremiumEntitlementStatus>{
      PremiumEntitlementStatus.trialing,
      PremiumEntitlementStatus.active,
      PremiumEntitlementStatus.revoked,
      PremiumEntitlementStatus.refunded,
    },
    PremiumEntitlementStatus.revoked ||
    PremiumEntitlementStatus.refunded => const <PremiumEntitlementStatus>{},
  };

  PremiumTransitionDecision _allow(PremiumTransitionReason reason) =>
      PremiumTransitionDecision(isAllowed: true, reason: reason);

  PremiumTransitionDecision _deny(PremiumTransitionReason reason) =>
      PremiumTransitionDecision(isAllowed: false, reason: reason);
}
