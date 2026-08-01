import 'package:meu_gestor_financeiro/features/owner_access/domain/access_context.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';

enum MasterAccessStatus {
  idle,
  loading,
  regularUser,
  activeOwner,
  revoked,
  invalidDocument,
  recoverableError,
}

final class MasterAccessState {
  MasterAccessState._({
    required this.status,
    required this.accessContext,
    this.failure,
  });

  factory MasterAccessState.idle() => MasterAccessState._(
    status: MasterAccessStatus.idle,
    accessContext: AccessContext.regularUser(),
  );

  factory MasterAccessState.loading() => MasterAccessState._(
    status: MasterAccessStatus.loading,
    accessContext: AccessContext.regularUser(),
  );

  factory MasterAccessState.regularUser() => MasterAccessState._(
    status: MasterAccessStatus.regularUser,
    accessContext: AccessContext.regularUser(),
  );

  factory MasterAccessState.activeOwner() => MasterAccessState._(
    status: MasterAccessStatus.activeOwner,
    accessContext: AccessContext.owner(),
  );

  factory MasterAccessState.revoked() => MasterAccessState._(
    status: MasterAccessStatus.revoked,
    accessContext: AccessContext.regularUser(),
  );

  factory MasterAccessState.invalidDocument(MasterAccessFailure failure) =>
      MasterAccessState._(
        status: MasterAccessStatus.invalidDocument,
        accessContext: AccessContext.regularUser(),
        failure: failure,
      );

  factory MasterAccessState.recoverableError(MasterAccessFailure failure) =>
      MasterAccessState._(
        status: MasterAccessStatus.recoverableError,
        accessContext: AccessContext.regularUser(),
        failure: failure,
      );

  final MasterAccessStatus status;
  final AccessContext accessContext;
  final MasterAccessFailure? failure;

  bool get isActiveOwner => status == MasterAccessStatus.activeOwner;
  bool get isLoading => status == MasterAccessStatus.loading;
}
