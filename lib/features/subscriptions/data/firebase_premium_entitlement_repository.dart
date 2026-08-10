import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firestore_premium_entitlement_mapper.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';

final class FirebasePremiumEntitlementRepository
    implements PremiumEntitlementRepository {
  FirebasePremiumEntitlementRepository({
    required FirebaseFirestore firestore,
    required PremiumEntitlementDiagnostics diagnostics,
  }) : _firestore = firestore,
       _diagnostics = diagnostics;

  static const Duration _timeout = Duration(seconds: 12);
  static const String entitlementId = 'premium';

  final FirebaseFirestore _firestore;
  final PremiumEntitlementDiagnostics _diagnostics;

  @override
  Future<PremiumEntitlementReadResult> readCurrent({
    required String ownerId,
    required bool serverOnly,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _reference(ownerId)
              .get(serverOnly ? const GetOptions(source: Source.server) : null)
              .timeout(_timeout);
      return decodeSnapshot(
        ownerId: ownerId,
        exists: snapshot.exists,
        data: snapshot.data(),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    } on Object catch (error) {
      throw _mapAndRecord('read_premium_entitlement', 'document_get', error);
    }
  }

  @override
  Future<PremiumEntitlementReadResult> refreshFromServer({
    required String ownerId,
  }) => readCurrent(ownerId: ownerId, serverOnly: true);

  @override
  Stream<PremiumEntitlementReadResult> watchConfirmed({
    required String ownerId,
  }) async* {
    try {
      await for (final DocumentSnapshot<Map<String, dynamic>> snapshot
          in _reference(ownerId).snapshots()) {
        if (snapshot.metadata.isFromCache ||
            snapshot.metadata.hasPendingWrites) {
          continue;
        }
        yield decodeSnapshot(
          ownerId: ownerId,
          exists: snapshot.exists,
          data: snapshot.data(),
          isFromCache: false,
          hasPendingWrites: false,
        );
      }
    } on Object catch (error) {
      throw _mapAndRecord('watch_premium_entitlement', 'snapshot', error);
    }
  }

  @override
  Future<PremiumEntitlementDiagnostic> readSanitizedDiagnostic({
    required String ownerId,
  }) async {
    final PremiumEntitlementReadResult result = await refreshFromServer(
      ownerId: ownerId,
    );
    final PremiumEntitlement? entitlement = result.entitlement;
    return PremiumEntitlementDiagnostic(
      code: entitlement == null ? 'premium_absent' : 'premium_present',
      isFromServer: result.isFromServer,
      schemaVersion: entitlement?.schemaVersion,
      revision: entitlement?.revision,
    );
  }

  @visibleForTesting
  static String documentPath(String ownerId) =>
      'users/$ownerId/entitlements/$entitlementId';

  @visibleForTesting
  static PremiumEntitlementReadResult decodeSnapshot({
    required String ownerId,
    required bool exists,
    required Map<String, dynamic>? data,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    if (!exists) {
      return PremiumEntitlementReadResult.absent(
        isFromServer: !isFromCache,
        hasPendingWrites: hasPendingWrites,
      );
    }
    if (data == null) {
      throw const PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.inconsistentData,
        safeMessage: 'Os dados do acesso Premium são incompatíveis.',
        code: 'premium_document_without_data',
      );
    }
    return PremiumEntitlementReadResult.present(
      entitlement: FirestorePremiumEntitlementMapper.fromMap(
        data: data,
        expectedOwnerId: ownerId,
      ),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  DocumentReference<Map<String, dynamic>> _reference(String ownerId) {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw const PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_premium_owner',
      );
    }
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('entitlements')
        .doc(entitlementId);
  }

  PremiumEntitlementFailure _mapAndRecord(
    String operation,
    String stage,
    Object error,
  ) {
    final PremiumEntitlementFailure failure = mapFailure(error);
    _diagnostics.record(
      operation: operation,
      stage: stage,
      category: failure.kind.name,
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  @visibleForTesting
  static PremiumEntitlementFailure mapFailure(Object error) {
    if (error is PremiumEntitlementFailure) return error;
    if (error is TimeoutException) {
      return const PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.serverConfirmationUnavailable,
        safeMessage: 'A confirmação do acesso Premium demorou demais.',
        code: 'premium_timeout',
      );
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'unauthenticated' => const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'permission-denied' => const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.permissionDenied,
          safeMessage: 'O acesso Premium não pôde ser confirmado.',
          code: 'permission-denied',
        ),
        'unavailable' => const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.unavailable,
          safeMessage: 'A confirmação Premium está indisponível no momento.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.serverConfirmationUnavailable,
          safeMessage: 'A confirmação do acesso Premium demorou demais.',
          code: 'deadline-exceeded',
        ),
        _ => const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.unknown,
          safeMessage: 'Não foi possível confirmar o acesso Premium.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const PremiumEntitlementFailure(
      kind: PremiumEntitlementFailureKind.unknown,
      safeMessage: 'Não foi possível confirmar o acesso Premium.',
      code: 'unknown_premium_read_error',
    );
  }
}
