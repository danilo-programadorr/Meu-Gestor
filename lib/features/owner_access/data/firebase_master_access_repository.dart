import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/firestore_master_access_mapper.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';

final class FirebaseMasterAccessRepository implements MasterAccessRepository {
  FirebaseMasterAccessRepository({
    required FirebaseFirestore firestore,
    required MasterAccessDiagnostics diagnostics,
  }) : _firestore = firestore,
       _diagnostics = diagnostics;

  static const String collectionName = 'system_admins';

  final FirebaseFirestore _firestore;
  final MasterAccessDiagnostics _diagnostics;

  @override
  Future<MasterAccessReadResult> readOwnAccess({
    required String userId,
    required bool serverOnly,
  }) async {
    if (userId.isEmpty) {
      throw const MasterAccessFailure(
        kind: MasterAccessFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'owner_access_missing_user',
      );
    }
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(collectionName)
          .doc(userId)
          .get(serverOnly ? const GetOptions(source: Source.server) : null);
      stopwatch.stop();
      final MasterAccessReadResult result = decodeReadSnapshot(
        exists: snapshot.exists,
        data: snapshot.data(),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
      _diagnostics.record(
        operation: 'read_owner_access',
        stage: 'document_get',
        duration: stopwatch.elapsed,
        finalState: result.decision.name,
      );
      return result;
    } on Object catch (error) {
      stopwatch.stop();
      final MasterAccessFailure failure = mapFailure(error);
      _diagnostics.record(
        operation: 'read_owner_access',
        stage: 'document_get',
        duration: stopwatch.elapsed,
        finalState: 'denied',
        error: error,
        firestoreCode: error is FirebaseException ? error.code : failure.code,
      );
      throw failure;
    }
  }

  @visibleForTesting
  static String documentPath(String userId) => '$collectionName/$userId';

  @visibleForTesting
  static MasterAccessReadResult decodeReadSnapshot({
    required bool exists,
    required Map<String, dynamic>? data,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    if (!exists) {
      return MasterAccessReadResult(
        decision: MasterAccessDecision.regularUser,
        access: null,
        isFromServer: !isFromCache,
        hasPendingWrites: hasPendingWrites,
      );
    }
    if (data == null) {
      throw const MasterAccessFailure(
        kind: MasterAccessFailureKind.conversion,
        safeMessage:
            'A autorização administrativa possui uma configuração incompatível.',
        code: 'owner_access_document_without_data',
      );
    }
    final MasterAccess access = FirestoreMasterAccessMapper.fromMap(data);
    return MasterAccessReadResult(
      decision: access.active
          ? MasterAccessDecision.activeOwner
          : MasterAccessDecision.revoked,
      access: access,
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @visibleForTesting
  static MasterAccessFailure mapFailure(Object error) {
    if (error is MasterAccessFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.permissionDenied,
          safeMessage: 'O acesso administrativo não pôde ser confirmado.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.unavailable,
          safeMessage:
              'A verificação administrativa está temporariamente indisponível.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.timeout,
          safeMessage: 'A verificação administrativa demorou demais.',
          code: 'deadline-exceeded',
        ),
        'not-found' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.notFound,
          safeMessage: 'A autorização administrativa não foi encontrada.',
          code: 'not-found',
        ),
        'data-loss' => const MasterAccessFailure(
          kind: MasterAccessFailureKind.dataLoss,
          safeMessage:
              'A autorização administrativa possui dados incompatíveis.',
          code: 'data-loss',
        ),
        _ => const MasterAccessFailure(
          kind: MasterAccessFailureKind.unknown,
          safeMessage: 'Não foi possível confirmar o acesso administrativo.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const MasterAccessFailure(
      kind: MasterAccessFailureKind.unknown,
      safeMessage: 'Não foi possível confirmar o acesso administrativo.',
      code: 'unknown_owner_access_error',
    );
  }
}
