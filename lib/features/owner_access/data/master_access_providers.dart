import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/firebase_master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

final Provider<MasterAccessDiagnostics> masterAccessDiagnosticsProvider =
    Provider<MasterAccessDiagnostics>(
      (Ref ref) => MasterAccessDiagnostics(
        environment: ref.watch(appEnvironmentProvider),
      ),
    );

final Provider<MasterAccessRepository> masterAccessRepositoryProvider =
    Provider<MasterAccessRepository>(
      (Ref ref) => FirebaseMasterAccessRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        diagnostics: ref.watch(masterAccessDiagnosticsProvider),
      ),
    );

final Provider<String?> masterAccessSubjectProvider = Provider<String?>((
  Ref ref,
) {
  if (ref.watch(appEnvironmentProvider) != AppEnvironment.development) {
    return null;
  }
  final AuthUser? user = ref.watch(authStateProvider).value;
  final ProfileGateState? profileGate = ref
      .watch(profileGateControllerProvider)
      .value;
  if (user == null ||
      !user.emailVerified ||
      profileGate is! ProfileGateValid ||
      profileGate.profile.ownerId != user.id) {
    return null;
  }
  return user.id;
});
