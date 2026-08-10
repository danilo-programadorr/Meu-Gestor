import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

import 'premium_test_fixtures.dart';

void main() {
  group('PremiumEntitlement', () {
    for (final PremiumEntitlementStatus status
        in PremiumEntitlementStatus.values) {
      test('cria estado válido ${status.name}', () {
        final PremiumEntitlement entitlement = premiumEntitlement(
          status: status,
          source: status == PremiumEntitlementStatus.pending
              ? PremiumEntitlementSource.googlePlay
              : PremiumEntitlementSource.developmentGrant,
        );
        expect(entitlement.status, status);
        expect(entitlement.capabilities, isNotEmpty);
      });
    }

    test('plano mensal e anual concedem as mesmas capabilities', () {
      expect(
        PremiumPlan.monthly.includedCapabilities,
        PremiumPlan.annual.includedCapabilities,
      );
      expect(PremiumPlan.free.includedCapabilities, isEmpty);
    });

    test('rejeita owner vazio ou não normalizado', () {
      for (final String ownerId in <String>['', '  ', ' owner ']) {
        expect(
          () => premiumEntitlement(ownerId: ownerId),
          throwsA(_failure(PremiumEntitlementFailureKind.inconsistentData)),
        );
      }
    });

    test('rejeita revisão e esquema inválidos', () {
      expect(
        () => premiumEntitlement(revision: 0),
        throwsA(_failure(PremiumEntitlementFailureKind.inconsistentData)),
      );
      expect(
        () => premiumEntitlement(schemaVersion: 2),
        throwsA(_failure(PremiumEntitlementFailureKind.incompatibleSchema)),
      );
    });

    test('rejeita capabilities duplicadas', () {
      expect(
        () => premiumEntitlement(
          capabilities: const <PremiumCapability>[
            PremiumCapability.investmentsManual,
            PremiumCapability.investmentsManual,
          ],
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.inconsistentData)),
      );
    });

    test('rejeita período incompleto, invertido e início incompatível', () {
      expect(
        () => PremiumEntitlement.create(
          ownerId: 'synthetic-owner',
          plan: PremiumPlan.monthly,
          status: PremiumEntitlementStatus.active,
          source: PremiumEntitlementSource.googlePlay,
          environment: PremiumEnvironment.development,
          capabilities: PremiumPlan.monthly.includedCapabilities,
          entitlementStartedAt: premiumStartedAt,
          currentPeriodStartedAt: premiumPeriodStartedAt,
          currentPeriodEndsAt: null,
          graceUntil: null,
          cancelAtPeriodEnd: false,
          cancelledAt: null,
          expiredAt: null,
          revokedAt: null,
          refundedAt: null,
          lastVerifiedAt: premiumLastVerifiedAt,
          revision: 1,
          schemaVersion: 1,
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
      expect(
        () => premiumEntitlement(
          currentPeriodStartedAt: premiumPeriodEndsAt,
          currentPeriodEndsAt: premiumPeriodStartedAt,
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
      expect(
        () =>
            premiumEntitlement(entitlementStartedAt: DateTime.utc(2026, 8, 15)),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
    });

    test('rejeita datas locais e verificação anterior ao entitlement', () {
      expect(
        () => premiumEntitlement(currentPeriodStartedAt: DateTime(2026, 8, 10)),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
      expect(
        () => premiumEntitlement(lastVerifiedAt: DateTime.utc(2026, 7, 31)),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
    });

    test('exige campos próprios de carência e cancelamento', () {
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.active,
          graceUntil: DateTime.utc(2026, 9, 17),
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidState)),
      );
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.cancelled,
          cancelAtPeriodEnd: false,
          cancelledAt: null,
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidState)),
      );
    });

    test('exige data exclusiva de expiração, revogação e reembolso', () {
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.expired,
          expiredAt: DateTime.utc(2026, 9, 1),
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.active,
          revokedAt: DateTime.utc(2026, 8, 15),
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidState)),
      );
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.refunded,
          refundedAt: DateTime.utc(2026, 8, 21),
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidPeriod)),
      );
    });

    test('concessão development exige ambiente e validade corretos', () {
      expect(
        () => premiumEntitlement(
          source: PremiumEntitlementSource.developmentGrant,
          environment: PremiumEnvironment.production,
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidState)),
      );
      expect(
        () => premiumEntitlement(
          status: PremiumEntitlementStatus.pending,
          source: PremiumEntitlementSource.developmentGrant,
        ),
        throwsA(_failure(PremiumEntitlementFailureKind.invalidState)),
      );
    });

    test('não aceita plano gratuito como entitlement Premium', () {
      expect(
        () => premiumEntitlement(plan: PremiumPlan.free),
        throwsA(_failure(PremiumEntitlementFailureKind.inconsistentData)),
      );
    });
  });
}

Matcher _failure(PremiumEntitlementFailureKind kind) =>
    isA<PremiumEntitlementFailure>().having(
      (PremiumEntitlementFailure value) => value.kind,
      'kind',
      kind,
    );
