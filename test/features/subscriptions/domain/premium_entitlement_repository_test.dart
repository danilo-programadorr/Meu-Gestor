import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';

import 'premium_test_fixtures.dart';

void main() {
  group('PremiumEntitlementRepository contract', () {
    test('representa entitlement ausente sem criar plano no cliente', () async {
      final PremiumEntitlementRepository repository = _FakeRepository(null);
      final PremiumEntitlementReadResult result = await repository.readCurrent(
        ownerId: 'synthetic-owner',
        serverOnly: true,
      );
      expect(result.presence, PremiumEntitlementPresence.absent);
      expect(result.entitlement, isNull);
      expect(result.isFromServer, isTrue);
      expect(result.hasPendingWrites, isFalse);
    });

    test(
      'observa somente snapshot confirmado e permite releitura do servidor',
      () async {
        final PremiumEntitlement entitlement = premiumEntitlement();
        final PremiumEntitlementRepository repository = _FakeRepository(
          entitlement,
        );
        final PremiumEntitlementReadResult watched = await repository
            .watchConfirmed(ownerId: entitlement.ownerId)
            .first;
        final PremiumEntitlementReadResult refreshed = await repository
            .refreshFromServer(ownerId: entitlement.ownerId);
        expect(watched.entitlement, same(entitlement));
        expect(watched.hasPendingWrites, isFalse);
        expect(refreshed.isFromServer, isTrue);
      },
    );

    test('diagnóstico não contém owner, token, recibo ou payload', () async {
      final PremiumEntitlementRepository repository = _FakeRepository(
        premiumEntitlement(),
      );
      final PremiumEntitlementDiagnostic diagnostic = await repository
          .readSanitizedDiagnostic(ownerId: 'synthetic-owner');
      expect(diagnostic.code, 'entitlement_present');
      expect(diagnostic.schemaVersion, 1);
      expect(diagnostic.revision, 1);
      expect(diagnostic.toString(), isNot(contains('synthetic-owner')));
    });
  });
}

final class _FakeRepository implements PremiumEntitlementRepository {
  const _FakeRepository(this.entitlement);

  final PremiumEntitlement? entitlement;

  PremiumEntitlementReadResult get _result => entitlement == null
      ? PremiumEntitlementReadResult.absent(
          isFromServer: true,
          hasPendingWrites: false,
        )
      : PremiumEntitlementReadResult.present(
          entitlement: entitlement!,
          isFromServer: true,
          hasPendingWrites: false,
        );

  @override
  Future<PremiumEntitlementReadResult> readCurrent({
    required String ownerId,
    required bool serverOnly,
  }) async => _result;

  @override
  Future<PremiumEntitlementDiagnostic> readSanitizedDiagnostic({
    required String ownerId,
  }) async => PremiumEntitlementDiagnostic(
    code: entitlement == null ? 'entitlement_absent' : 'entitlement_present',
    isFromServer: true,
    schemaVersion: entitlement?.schemaVersion,
    revision: entitlement?.revision,
  );

  @override
  Future<PremiumEntitlementReadResult> refreshFromServer({
    required String ownerId,
  }) async => _result;

  @override
  Stream<PremiumEntitlementReadResult> watchConfirmed({
    required String ownerId,
  }) => Stream<PremiumEntitlementReadResult>.value(_result);
}
