import 'dart:async';

import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';

final class FakeMasterAccessRepository implements MasterAccessRepository {
  FakeMasterAccessRepository({MasterAccessReadResult? result})
    : result = result ?? regularUserResult();

  MasterAccessReadResult result;
  MasterAccessFailure? nextFailure;
  Completer<void>? barrier;
  int readCalls = 0;
  final List<String> requestedUserIds = <String>[];
  final List<bool> serverOnlyRequests = <bool>[];

  @override
  Future<MasterAccessReadResult> readOwnAccess({
    required String userId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    requestedUserIds.add(userId);
    serverOnlyRequests.add(serverOnly);
    final Completer<void>? currentBarrier = barrier;
    if (currentBarrier != null) {
      await currentBarrier.future;
    }
    final MasterAccessFailure? failure = nextFailure;
    if (failure != null) {
      throw failure;
    }
    return result;
  }

  static MasterAccessReadResult regularUserResult({
    bool isFromServer = true,
    bool hasPendingWrites = false,
  }) => MasterAccessReadResult(
    decision: MasterAccessDecision.regularUser,
    access: null,
    isFromServer: isFromServer,
    hasPendingWrites: hasPendingWrites,
  );

  static MasterAccessReadResult activeOwnerResult({
    bool isFromServer = true,
    bool hasPendingWrites = false,
  }) => MasterAccessReadResult(
    decision: MasterAccessDecision.activeOwner,
    access: MasterAccess(
      role: AppRole.owner,
      active: true,
      environment: MasterAccess.supportedEnvironment,
      grantedAt: DateTime.utc(2026, 8, 1),
      schemaVersion: MasterAccess.currentSchemaVersion,
    ),
    isFromServer: isFromServer,
    hasPendingWrites: hasPendingWrites,
  );

  static MasterAccessReadResult revokedResult() => MasterAccessReadResult(
    decision: MasterAccessDecision.revoked,
    access: MasterAccess(
      role: AppRole.owner,
      active: false,
      environment: MasterAccess.supportedEnvironment,
      grantedAt: DateTime.utc(2026, 8, 1),
      schemaVersion: MasterAccess.currentSchemaVersion,
    ),
    isFromServer: true,
    hasPendingWrites: false,
  );
}
