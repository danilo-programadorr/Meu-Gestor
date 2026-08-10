import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_policy.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';

import 'premium_test_fixtures.dart';

void main() {
  const PremiumEntitlementTransitionPolicy policy =
      PremiumEntitlementTransitionPolicy();

  PremiumTransitionDecision transition(
    PremiumEntitlementStatus from,
    PremiumEntitlementStatus to, {
    int currentRevision = 1,
    int nextRevision = 2,
    DateTime? currentEnd,
    DateTime? nextStart,
    DateTime? nextEnd,
    DateTime? nextVerified,
  }) => policy.decide(
    current: premiumEntitlement(
      status: from,
      revision: currentRevision,
      currentPeriodEndsAt: currentEnd,
    ),
    next: premiumEntitlement(
      status: to,
      revision: nextRevision,
      currentPeriodStartedAt: nextStart,
      currentPeriodEndsAt: nextEnd,
      lastVerifiedAt: nextVerified ?? DateTime.utc(2026, 10, 20),
    ),
  );

  group('PremiumEntitlementTransitionPolicy', () {
    test('permite transições canônicas solicitadas', () {
      final List<(PremiumEntitlementStatus, PremiumEntitlementStatus)>
      cases = <(PremiumEntitlementStatus, PremiumEntitlementStatus)>[
        (PremiumEntitlementStatus.pending, PremiumEntitlementStatus.active),
        (PremiumEntitlementStatus.active, PremiumEntitlementStatus.cancelled),
        (PremiumEntitlementStatus.active, PremiumEntitlementStatus.gracePeriod),
        (PremiumEntitlementStatus.gracePeriod, PremiumEntitlementStatus.active),
        (
          PremiumEntitlementStatus.gracePeriod,
          PremiumEntitlementStatus.accountHold,
        ),
        (PremiumEntitlementStatus.active, PremiumEntitlementStatus.paused),
        (PremiumEntitlementStatus.cancelled, PremiumEntitlementStatus.expired),
      ];
      for (final (PremiumEntitlementStatus from, PremiumEntitlementStatus to)
          in cases) {
        expect(transition(from, to).isAllowed, isTrue, reason: '$from -> $to');
      }
    });

    test('permite revogação imediata de qualquer estado não terminal', () {
      for (final PremiumEntitlementStatus status
          in PremiumEntitlementStatus.values.where(
            (PremiumEntitlementStatus value) => !value.isTerminal,
          )) {
        expect(
          transition(status, PremiumEntitlementStatus.revoked).isAllowed,
          isTrue,
          reason: status.name,
        );
      }
    });

    test('permite reembolso somente nos estados aplicáveis', () {
      for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
        PremiumEntitlementStatus.active,
        PremiumEntitlementStatus.gracePeriod,
        PremiumEntitlementStatus.accountHold,
        PremiumEntitlementStatus.paused,
        PremiumEntitlementStatus.cancelled,
        PremiumEntitlementStatus.expired,
      ]) {
        expect(
          transition(status, PremiumEntitlementStatus.refunded).isAllowed,
          isTrue,
          reason: status.name,
        );
      }
      expect(
        transition(
          PremiumEntitlementStatus.pending,
          PremiumEntitlementStatus.refunded,
        ).isAllowed,
        isFalse,
      );
    });

    test(
      'evento antigo e revisão repetida são ignorados deterministicamente',
      () {
        expect(
          transition(
            PremiumEntitlementStatus.active,
            PremiumEntitlementStatus.cancelled,
            currentRevision: 3,
            nextRevision: 2,
          ).reason,
          PremiumTransitionReason.staleRevision,
        );
        expect(
          transition(
            PremiumEntitlementStatus.active,
            PremiumEntitlementStatus.cancelled,
            currentRevision: 3,
            nextRevision: 3,
          ).reason,
          PremiumTransitionReason.repeatedRevision,
        );
      },
    );

    test('renovação exige novo período sem reduzir o anterior', () {
      expect(
        transition(
          PremiumEntitlementStatus.active,
          PremiumEntitlementStatus.active,
          nextEnd: DateTime.utc(2026, 10, 10),
        ).reason,
        PremiumTransitionReason.renewal,
      );
      expect(
        transition(
          PremiumEntitlementStatus.active,
          PremiumEntitlementStatus.active,
        ).reason,
        PremiumTransitionReason.periodRegression,
      );
      expect(
        transition(
          PremiumEntitlementStatus.active,
          PremiumEntitlementStatus.cancelled,
          nextEnd: DateTime.utc(2026, 9, 1),
        ).reason,
        PremiumTransitionReason.periodRegression,
      );
    });

    test('cancelamento não expira imediatamente', () {
      final PremiumTransitionDecision decision = transition(
        PremiumEntitlementStatus.active,
        PremiumEntitlementStatus.cancelled,
      );
      expect(decision.isAllowed, isTrue);
      expect(decision.reason, PremiumTransitionReason.lifecycleProgression);
    });

    test('expirado pode iniciar nova assinatura com período posterior', () {
      final PremiumTransitionDecision decision = transition(
        PremiumEntitlementStatus.expired,
        PremiumEntitlementStatus.active,
        nextStart: DateTime.utc(2026, 9, 11),
        nextEnd: DateTime.utc(2026, 10, 11),
      );
      expect(decision.isAllowed, isTrue);
      expect(decision.reason, PremiumTransitionReason.newSubscription);
    });

    test('nega restauração de revogado e reembolsado', () {
      for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
        PremiumEntitlementStatus.revoked,
        PremiumEntitlementStatus.refunded,
      ]) {
        expect(
          transition(status, PremiumEntitlementStatus.active).reason,
          PremiumTransitionReason.terminalState,
        );
      }
      expect(
        policy
            .decide(
              current: premiumEntitlement(
                status: PremiumEntitlementStatus.revoked,
              ),
              next: premiumEntitlement(
                source: PremiumEntitlementSource.administrativeGrant,
                revision: 2,
              ),
            )
            .reason,
        PremiumTransitionReason.terminalState,
      );
    });

    test('nega transição não prevista e regressão de verificação', () {
      expect(
        transition(
          PremiumEntitlementStatus.pending,
          PremiumEntitlementStatus.paused,
        ).reason,
        PremiumTransitionReason.unsupportedTransition,
      );
      expect(
        transition(
          PremiumEntitlementStatus.active,
          PremiumEntitlementStatus.cancelled,
          nextVerified: DateTime.utc(2026, 8, 19),
        ).reason,
        PremiumTransitionReason.verificationRegression,
      );
    });

    test('nega troca de owner e ambiente no mesmo fluxo', () {
      final PremiumEntitlement current = premiumEntitlement();
      expect(
        policy
            .decide(
              current: current,
              next: premiumEntitlement(ownerId: 'another-owner', revision: 2),
            )
            .reason,
        PremiumTransitionReason.ownerMismatch,
      );
      expect(
        policy
            .decide(
              current: current,
              next: premiumEntitlement(
                source: PremiumEntitlementSource.administrativeGrant,
                revision: 2,
              ),
            )
            .reason,
        PremiumTransitionReason.sourceMismatch,
      );
      expect(
        policy
            .decide(
              current: current,
              next: premiumEntitlement(
                environment: PremiumEnvironment.production,
                revision: 2,
              ),
            )
            .reason,
        PremiumTransitionReason.environmentMismatch,
      );
    });
  });
}
