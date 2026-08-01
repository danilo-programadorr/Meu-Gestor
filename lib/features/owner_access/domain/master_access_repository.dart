import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access.dart';

enum MasterAccessDecision { regularUser, activeOwner, revoked }

final class MasterAccessReadResult {
  const MasterAccessReadResult({
    required this.decision,
    required this.access,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final MasterAccessDecision decision;
  final MasterAccess? access;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class MasterAccessRepository {
  Future<MasterAccessReadResult> readOwnAccess({
    required String userId,
    required bool serverOnly,
  });
}
