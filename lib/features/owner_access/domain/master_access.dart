import 'package:meu_gestor_financeiro/features/owner_access/domain/access_context.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';

final class MasterAccess {
  const MasterAccess({
    required this.role,
    required this.active,
    required this.environment,
    required this.grantedAt,
    required this.schemaVersion,
  });

  static const String supportedEnvironment = 'development';
  static const int currentSchemaVersion = 1;

  final AppRole role;
  final bool active;
  final String environment;
  final DateTime grantedAt;
  final int schemaVersion;

  bool get isActiveOwner =>
      role == AppRole.owner &&
      active &&
      environment == supportedEnvironment &&
      schemaVersion == currentSchemaVersion;

  AccessContext get accessContext =>
      isActiveOwner ? AccessContext.owner() : AccessContext.regularUser();
}
