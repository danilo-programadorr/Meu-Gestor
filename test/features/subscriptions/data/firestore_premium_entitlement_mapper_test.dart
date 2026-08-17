import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firestore_premium_entitlement_mapper.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';

void main() {
  final DateTime started = DateTime.utc(2026, 8, 1);
  final DateTime ends = DateTime.utc(2026, 9, 1);
  final DateTime verified = DateTime.utc(2026, 8, 10);

  Map<String, dynamic> valid({Map<String, dynamic> changes = const {}}) =>
      <String, dynamic>{
        'ownerId': 'synthetic-owner',
        'planId': 'monthly',
        'status': 'active',
        'source': 'googlePlay',
        'environment': 'development',
        'capabilities': <String>['investmentsManual', 'investmentIncome'],
        'startedAt': Timestamp.fromDate(started),
        'currentPeriodStart': Timestamp.fromDate(started),
        'currentPeriodEnd': Timestamp.fromDate(ends),
        'graceUntil': null,
        'cancelAtPeriodEnd': false,
        'cancelledAt': null,
        'expiredAt': null,
        'revokedAt': null,
        'refundedAt': null,
        'lastVerifiedAt': Timestamp.fromDate(verified),
        'revision': 1,
        'schemaVersion': 1,
        'createdAt': Timestamp.fromDate(started),
        'updatedAt': Timestamp.fromDate(verified),
        ...changes,
      };

  test('decodes exact server projection', () {
    final entitlement = FirestorePremiumEntitlementMapper.fromMap(
      data: valid(),
      expectedOwnerId: 'synthetic-owner',
    );
    expect(entitlement.status, PremiumEntitlementStatus.active);
    expect(entitlement.revision, 1);
    expect(entitlement.capabilities, hasLength(2));
  });

  test('decodes closed test only in its active or expired server form', () {
    final active = FirestorePremiumEntitlementMapper.fromMap(
      data: valid(
        changes: <String, dynamic>{
          'source': 'closedTestGrant',
          'capabilities': <String>[
            'investmentsManual',
            'investmentIncome',
            'investmentQuotes',
            'investmentCalculators',
            'investmentAnalysis',
          ],
        },
      ),
      expectedOwnerId: 'synthetic-owner',
    );
    expect(active.source, PremiumEntitlementSource.closedTestGrant);

    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(changes: <String, dynamic>{'source': 'closedTestGrant'}),
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
  });

  test('rejects extra and missing fields', () {
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(changes: <String, dynamic>{'extra': true}),
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
    final Map<String, dynamic> missing = valid()..remove('revision');
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: missing,
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
  });

  test('rejects cross-user document', () {
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(),
        expectedOwnerId: 'another-owner',
      ),
      throwsA(
        isA<PremiumEntitlementFailure>().having(
          (failure) => failure.code,
          'code',
          'premium_owner_mismatch',
        ),
      ),
    );
  });

  test('rejects unknown enum and capability', () {
    for (final Map<String, dynamic> changes in <Map<String, dynamic>>[
      <String, dynamic>{'status': 'unknown'},
      <String, dynamic>{'planId': 'lifetime'},
      <String, dynamic>{
        'capabilities': <String>['unknown'],
      },
    ]) {
      expect(
        () => FirestorePremiumEntitlementMapper.fromMap(
          data: valid(changes: changes),
          expectedOwnerId: 'synthetic-owner',
        ),
        throwsA(isA<PremiumEntitlementFailure>()),
      );
    }
  });

  test('rejects duplicated capability and wrong types', () {
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(
          changes: <String, dynamic>{
            'capabilities': <String>['investmentsManual', 'investmentsManual'],
          },
        ),
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(changes: <String, dynamic>{'revision': 1.0}),
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
  });

  test('rejects audit timestamps out of order', () {
    expect(
      () => FirestorePremiumEntitlementMapper.fromMap(
        data: valid(
          changes: <String, dynamic>{
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 31)),
          },
        ),
        expectedOwnerId: 'synthetic-owner',
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
  });
}
