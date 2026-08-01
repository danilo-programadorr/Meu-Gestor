import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

String? verifiedFinancialOwner(Ref ref) {
  final AuthRepository authRepository = ref.read(authRepositoryProvider);
  final AuthUser? user = authRepository.currentUser;
  final ProfileGateState? gate = ref.read(profileGateControllerProvider).value;
  if (user == null ||
      !user.emailVerified ||
      gate is! ProfileGateValid ||
      gate.profile.ownerId != user.id ||
      !gate.profile.hasCurrentLegalVersions) {
    return null;
  }
  return user.id;
}
