import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_access_decision.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_policy.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';

import 'premium_test_fixtures.dart';

void main() {
  const PremiumEntitlementPolicy policy = PremiumEntitlementPolicy(
    environment: PremiumEnvironment.development,
    maximumVerificationAge: Duration(days: 30),
  );

  PremiumAccessDecision decide(
    PremiumEntitlement? entitlement,
    DateTime instant, {
    PremiumCapability capability = PremiumCapability.investmentsManual,
    PremiumAccessIntent intent = PremiumAccessIntent.mutate,
  }) => policy.decide(
    entitlement: entitlement,
    capability: capability,
    intent: intent,
    referenceInstant: instant,
  );

  group('PremiumEntitlementPolicy', () {
    test('active permite imediatamente antes e nega no vencimento e após', () {
      final PremiumEntitlement active = premiumEntitlement();
      expect(
        decide(
          active,
          premiumPeriodEndsAt.subtract(const Duration(microseconds: 1)),
        ).isAllowed,
        isTrue,
      );
      expect(decide(active, premiumPeriodEndsAt).isAllowed, isFalse);
      expect(
        decide(
          active,
          premiumPeriodEndsAt.add(const Duration(seconds: 1)),
        ).reason,
        PremiumAccessReason.expired,
      );
    });

    test('trialing permite somente durante o período válido', () {
      final PremiumEntitlement trial = premiumEntitlement(
        status: PremiumEntitlementStatus.trialing,
      );
      expect(
        decide(trial, DateTime.utc(2026, 8, 15)).reason,
        PremiumAccessReason.trialing,
      );
      expect(decide(trial, premiumPeriodEndsAt).isAllowed, isFalse);
    });

    test('active antes do início é negado', () {
      final PremiumAccessDecision result = decide(
        premiumEntitlement(),
        premiumPeriodStartedAt.subtract(const Duration(microseconds: 1)),
      );
      expect(result.reason, PremiumAccessReason.notYetValid);
      expect(result.isAllowed, isFalse);
    });

    test('carência permite antes e nega no limite e depois', () {
      final PremiumEntitlement grace = premiumEntitlement(
        status: PremiumEntitlementStatus.gracePeriod,
      );
      final DateTime limit = grace.graceUntil!;
      final PremiumAccessDecision before = decide(
        grace,
        limit.subtract(const Duration(microseconds: 1)),
      );
      expect(before.isAllowed, isTrue);
      expect(before.isGracePeriod, isTrue);
      expect(before.requiresServerVerification, isTrue);
      expect(decide(grace, limit).isAllowed, isFalse);
      expect(
        decide(grace, limit.add(const Duration(seconds: 1))).isAllowed,
        isFalse,
      );
    });

    test('cancelado mantém acesso somente até o fim pago', () {
      final PremiumEntitlement cancelled = premiumEntitlement(
        status: PremiumEntitlementStatus.cancelled,
      );
      final PremiumAccessDecision valid = decide(
        cancelled,
        DateTime.utc(2026, 9, 1),
      );
      expect(valid.mode, PremiumAccessMode.full);
      expect(valid.isCancellationPending, isTrue);
      expect(valid.validUntil, premiumPeriodEndsAt);
      expect(decide(cancelled, premiumPeriodEndsAt).isAllowed, isFalse);
    });

    test('pending, account hold e paused não concedem mutação', () {
      final Map<PremiumEntitlementStatus, PremiumAccessReason> cases =
          <PremiumEntitlementStatus, PremiumAccessReason>{
            PremiumEntitlementStatus.pending:
                PremiumAccessReason.pendingServerConfirmation,
            PremiumEntitlementStatus.accountHold:
                PremiumAccessReason.accountHold,
            PremiumEntitlementStatus.paused: PremiumAccessReason.paused,
          };
      for (final MapEntry<PremiumEntitlementStatus, PremiumAccessReason> entry
          in cases.entries) {
        expect(
          decide(
            premiumEntitlement(status: entry.key),
            DateTime.utc(2026, 8, 21),
          ).reason,
          entry.value,
        );
      }
    });

    test('pending e ausência negam também a leitura', () {
      expect(
        decide(
          null,
          DateTime.utc(2026, 8, 21),
          intent: PremiumAccessIntent.read,
        ).mode,
        PremiumAccessMode.denied,
      );
      expect(
        decide(
          premiumEntitlement(status: PremiumEntitlementStatus.pending),
          DateTime.utc(2026, 8, 21),
          intent: PremiumAccessIntent.read,
        ).mode,
        PremiumAccessMode.denied,
      );
    });

    test('revogação e reembolso prevalecem sobre período futuro', () {
      for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
        PremiumEntitlementStatus.revoked,
        PremiumEntitlementStatus.refunded,
      ]) {
        final PremiumAccessDecision result = decide(
          premiumEntitlement(status: status),
          DateTime.utc(2026, 8, 16),
        );
        expect(result.isAllowed, isFalse);
        expect(
          result.reason,
          status == PremiumEntitlementStatus.revoked
              ? PremiumAccessReason.revoked
              : PremiumAccessReason.refunded,
        );
      }
    });

    test('capability presente é permitida e ausente é negada', () {
      final PremiumEntitlement limited = premiumEntitlement(
        capabilities: const <PremiumCapability>{
          PremiumCapability.investmentsManual,
        },
      );
      expect(decide(limited, DateTime.utc(2026, 8, 21)).isAllowed, isTrue);
      expect(
        decide(
          limited,
          DateTime.utc(2026, 8, 21),
          capability: PremiumCapability.investmentAnalysis,
          intent: PremiumAccessIntent.consumeService,
        ).reason,
        PremiumAccessReason.capabilityNotGranted,
      );
      expect(
        decide(
          limited,
          DateTime.utc(2026, 8, 21),
          capability: PremiumCapability.investmentIncome,
          intent: PremiumAccessIntent.read,
        ).mode,
        PremiumAccessMode.denied,
      );
    });

    test('perda de Premium preserva leitura e bloqueia mutação dos dados', () {
      final PremiumEntitlement expired = premiumEntitlement(
        status: PremiumEntitlementStatus.expired,
      );
      final PremiumAccessDecision read = decide(
        expired,
        DateTime.utc(2026, 9, 11),
        intent: PremiumAccessIntent.read,
      );
      expect(read.mode, PremiumAccessMode.readOnly);
      expect(read.reason, PremiumAccessReason.retainedDataReadOnly);
      expect(
        decide(expired, DateTime.utc(2026, 9, 11)).mode,
        PremiumAccessMode.denied,
      );
    });

    test('proventos preservam leitura após expiração', () {
      final PremiumAccessDecision read = decide(
        premiumEntitlement(status: PremiumEntitlementStatus.expired),
        DateTime.utc(2026, 9, 11),
        capability: PremiumCapability.investmentIncome,
        intent: PremiumAccessIntent.read,
      );
      expect(read.mode, PremiumAccessMode.readOnly);
    });

    test('cotação é negada após expiração e sem entitlement', () {
      for (final PremiumEntitlement? entitlement in <PremiumEntitlement?>[
        premiumEntitlement(status: PremiumEntitlementStatus.expired),
        null,
      ]) {
        final PremiumAccessDecision result = decide(
          entitlement,
          DateTime.utc(2026, 9, 11),
          capability: PremiumCapability.investmentQuotes,
          intent: PremiumAccessIntent.consumeService,
        );
        expect(result.mode, PremiumAccessMode.denied);
      }
    });

    test('ambiente divergente falha fechado inclusive para leitura', () {
      const PremiumEntitlementPolicy productionPolicy =
          PremiumEntitlementPolicy(environment: PremiumEnvironment.production);
      final PremiumEntitlement grant = premiumEntitlement(
        source: PremiumEntitlementSource.developmentGrant,
      );
      expect(
        productionPolicy
            .decide(
              entitlement: grant,
              capability: PremiumCapability.investmentsManual,
              intent: PremiumAccessIntent.mutate,
              referenceInstant: DateTime.utc(2026, 8, 21),
            )
            .reason,
        PremiumAccessReason.environmentMismatch,
      );
      expect(
        productionPolicy
            .decide(
              entitlement: grant,
              capability: PremiumCapability.investmentsManual,
              intent: PremiumAccessIntent.read,
              referenceInstant: DateTime.utc(2026, 8, 21),
            )
            .mode,
        PremiumAccessMode.denied,
      );
    });

    test('estados com acesso anterior preservam somente leitura', () {
      for (final PremiumEntitlementStatus status in <PremiumEntitlementStatus>[
        PremiumEntitlementStatus.accountHold,
        PremiumEntitlementStatus.paused,
        PremiumEntitlementStatus.expired,
        PremiumEntitlementStatus.revoked,
        PremiumEntitlementStatus.refunded,
      ]) {
        final PremiumAccessDecision result = decide(
          premiumEntitlement(status: status),
          DateTime.utc(2026, 9, 11),
          intent: PremiumAccessIntent.read,
        );
        expect(result.mode, PremiumAccessMode.readOnly, reason: status.name);
      }
    });

    test('verificação antiga sinaliza releitura sem usar relógio real', () {
      const PremiumEntitlementPolicy shortPolicy = PremiumEntitlementPolicy(
        environment: PremiumEnvironment.development,
        maximumVerificationAge: Duration(days: 1),
      );
      final PremiumAccessDecision result = shortPolicy.decide(
        entitlement: premiumEntitlement(),
        capability: PremiumCapability.investmentsManual,
        intent: PremiumAccessIntent.mutate,
        referenceInstant: DateTime.utc(2026, 8, 22, 0, 0, 1),
      );
      expect(result.isAllowed, isTrue);
      expect(result.requiresServerVerification, isTrue);
    });

    test('rejeita instante local e janela de verificação inválida', () {
      expect(
        () => decide(premiumEntitlement(), DateTime(2026, 8, 21)),
        throwsArgumentError,
      );
      const PremiumEntitlementPolicy invalidPolicy = PremiumEntitlementPolicy(
        environment: PremiumEnvironment.development,
        maximumVerificationAge: Duration.zero,
      );
      expect(
        () => invalidPolicy.decide(
          entitlement: premiumEntitlement(),
          capability: PremiumCapability.investmentsManual,
          intent: PremiumAccessIntent.read,
          referenceInstant: DateTime.utc(2026, 8, 21),
        ),
        throwsArgumentError,
      );
    });
  });
}
