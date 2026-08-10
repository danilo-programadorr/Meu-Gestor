import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';

enum PremiumAccessMode { full, readOnly, denied }

enum PremiumAccessReason {
  active,
  trialing,
  gracePeriod,
  cancelledUntilPeriodEnd,
  retainedDataReadOnly,
  missingEntitlement,
  pendingServerConfirmation,
  environmentMismatch,
  capabilityNotGranted,
  notYetValid,
  expired,
  accountHold,
  paused,
  revoked,
  refunded,
}

final class PremiumAccessDecision {
  const PremiumAccessDecision({
    required this.mode,
    required this.reason,
    required this.capability,
    required this.intent,
    required this.validUntil,
    required this.isGracePeriod,
    required this.isCancellationPending,
    required this.requiresServerVerification,
  });

  final PremiumAccessMode mode;
  final PremiumAccessReason reason;
  final PremiumCapability capability;
  final PremiumAccessIntent intent;
  final DateTime? validUntil;
  final bool isGracePeriod;
  final bool isCancellationPending;
  final bool requiresServerVerification;

  bool get isAllowed => mode != PremiumAccessMode.denied;
}
