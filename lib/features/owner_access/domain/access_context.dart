import 'package:meu_gestor_financeiro/features/owner_access/domain/app_capability.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';

final class AccessContext {
  AccessContext._({
    required this.role,
    required Set<AppCapability> capabilities,
  }) : capabilities = Set<AppCapability>.unmodifiable(capabilities);

  factory AccessContext.regularUser() => AccessContext._(
    role: AppRole.regularUser,
    capabilities: const <AppCapability>{},
  );

  factory AccessContext.owner() => AccessContext._(
    role: AppRole.owner,
    capabilities: AppCapability.values.toSet(),
  );

  final AppRole role;
  final Set<AppCapability> capabilities;

  bool allows(AppCapability capability) => capabilities.contains(capability);

  bool allowsIdentifier(String identifier) {
    for (final AppCapability capability in AppCapability.values) {
      if (capability.name == identifier) {
        return allows(capability);
      }
    }
    return false;
  }
}
