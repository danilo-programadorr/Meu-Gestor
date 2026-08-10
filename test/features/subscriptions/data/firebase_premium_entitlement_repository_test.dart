import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firebase_premium_entitlement_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';

void main() {
  test('uses only the own fixed entitlement path', () {
    expect(
      FirebasePremiumEntitlementRepository.documentPath('synthetic-owner'),
      'users/synthetic-owner/entitlements/premium',
    );
  });

  test('represents absent server document explicitly', () {
    final PremiumEntitlementReadResult result =
        FirebasePremiumEntitlementRepository.decodeSnapshot(
          ownerId: 'synthetic-owner',
          exists: false,
          data: null,
          isFromCache: false,
          hasPendingWrites: false,
        );
    expect(result.presence, PremiumEntitlementPresence.absent);
    expect(result.entitlement, isNull);
    expect(result.isFromServer, isTrue);
  });

  test('does not treat cache absence as server confirmation', () {
    final PremiumEntitlementReadResult result =
        FirebasePremiumEntitlementRepository.decodeSnapshot(
          ownerId: 'synthetic-owner',
          exists: false,
          data: null,
          isFromCache: true,
          hasPendingWrites: false,
        );
    expect(result.isFromServer, isFalse);
  });

  test('rejects existing snapshot without data', () {
    expect(
      () => FirebasePremiumEntitlementRepository.decodeSnapshot(
        ownerId: 'synthetic-owner',
        exists: true,
        data: null,
        isFromCache: false,
        hasPendingWrites: false,
      ),
      throwsA(isA<PremiumEntitlementFailure>()),
    );
  });

  test('maps timeout and Firebase failures to sanitized kinds', () {
    expect(
      FirebasePremiumEntitlementRepository.mapFailure(
        TimeoutException('synthetic detail'),
      ).kind,
      PremiumEntitlementFailureKind.serverConfirmationUnavailable,
    );
    expect(
      FirebasePremiumEntitlementRepository.mapFailure(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ).kind,
      PremiumEntitlementFailureKind.permissionDenied,
    );
    expect(
      FirebasePremiumEntitlementRepository.mapFailure(
        FirebaseException(plugin: 'firestore', code: 'unavailable'),
      ).kind,
      PremiumEntitlementFailureKind.unavailable,
    );
  });
}
