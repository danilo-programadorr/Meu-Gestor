import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

final NotifierProvider<ProfileActionController, ProfileActionState>
profileActionControllerProvider =
    NotifierProvider<ProfileActionController, ProfileActionState>(
      ProfileActionController.new,
    );

final class ProfileActionController extends Notifier<ProfileActionState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  UserProfileRepository get _profileRepository =>
      ref.read(userProfileRepositoryProvider);

  @override
  ProfileActionState build() => const ProfileActionState.idle();

  void clearMessage() {
    if (!state.isLoading) {
      state = const ProfileActionState.idle();
    }
  }

  Future<void> createProfile({
    required String displayName,
    required bool termsAccepted,
    required bool privacyAccepted,
    required bool aiConsentEnabled,
    required bool analyticsConsentEnabled,
  }) async {
    if (state.isLoading) {
      return;
    }
    if (!termsAccepted || !privacyAccepted) {
      state = const ProfileActionState.failure(
        message:
            'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
      );
      return;
    }
    final String normalized;
    try {
      normalized = DisplayName.requireValid(displayName);
    } on ValidationException catch (error) {
      state = ProfileActionState.failure(message: error.message);
      return;
    }

    state = const ProfileActionState.loading();
    try {
      final AuthVerificationSnapshot verification = await _verifiedIdentity();
      final String ownerId = verification.user!.id;
      final UserProfileCreationResult result = await _profileRepository
          .createIfAbsent(
            UserProfileCreation(
              ownerId: ownerId,
              displayName: normalized,
              aiConsentEnabled: aiConsentEnabled,
              analyticsConsentEnabled: analyticsConsentEnabled,
            ),
          );
      ref
          .read(profileGateControllerProvider.notifier)
          .replaceProfile(result.profile);
      state = ProfileActionState.success(
        profile: result.profile,
        message: result.wasCreated
            ? 'Perfil criado com segurança.'
            : 'Seu perfil existente foi mantido.',
      );
    } on UserProfileFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on AuthFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const ProfileActionState.failure(
        message: 'Não foi possível criar seu perfil. Tente novamente.',
      );
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    if (state.isLoading) {
      return;
    }
    final String normalized;
    try {
      normalized = DisplayName.requireValid(displayName);
    } on ValidationException catch (error) {
      state = ProfileActionState.failure(message: error.message);
      return;
    }

    state = const ProfileActionState.loading();
    try {
      final AuthVerificationSnapshot verification = await _verifiedIdentity();
      final UserProfile profile = await _profileRepository.updateDisplayName(
        ownerId: verification.user!.id,
        displayName: normalized,
      );
      ref.read(profileGateControllerProvider.notifier).replaceProfile(profile);
      try {
        await _authRepository.updateDisplayName(normalized);
        state = ProfileActionState.success(
          profile: profile,
          message: 'Nome atualizado.',
        );
      } on Object {
        state = ProfileActionState.success(
          profile: profile,
          message:
              'O nome foi salvo no perfil, mas não foi espelhado no acesso. Tente novamente mais tarde.',
          hasPartialFailure: true,
        );
      }
    } on UserProfileFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on AuthFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const ProfileActionState.failure(
        message: 'Não foi possível atualizar o nome. Tente novamente.',
      );
    }
  }

  Future<void> updateOptionalConsents({
    required bool aiConsentEnabled,
    required bool analyticsConsentEnabled,
  }) async {
    if (state.isLoading) {
      return;
    }
    state = const ProfileActionState.loading();
    try {
      final AuthVerificationSnapshot verification = await _verifiedIdentity();
      final UserProfile profile = await _profileRepository
          .updateOptionalConsents(
            ownerId: verification.user!.id,
            aiConsentEnabled: aiConsentEnabled,
            analyticsConsentEnabled: analyticsConsentEnabled,
          );
      ref.read(profileGateControllerProvider.notifier).replaceProfile(profile);
      state = ProfileActionState.success(
        profile: profile,
        message: 'Preferências salvas com segurança.',
      );
    } on UserProfileFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on AuthFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const ProfileActionState.failure(
        message: 'Não foi possível salvar as preferências. Tente novamente.',
      );
    }
  }

  Future<void> acceptCurrentLegalVersions({
    required bool termsAccepted,
    required bool privacyAccepted,
  }) async {
    if (state.isLoading) {
      return;
    }
    if (!termsAccepted || !privacyAccepted) {
      state = const ProfileActionState.failure(
        message:
            'Confirme os Termos de Uso e a Política de Privacidade para continuar.',
      );
      return;
    }
    state = const ProfileActionState.loading();
    try {
      final AuthVerificationSnapshot verification = await _verifiedIdentity();
      final UserProfile profile = await _profileRepository
          .acceptCurrentLegalVersions(ownerId: verification.user!.id);
      ref.read(profileGateControllerProvider.notifier).replaceProfile(profile);
      state = ProfileActionState.success(
        profile: profile,
        message: 'Novas versões aceitas com segurança.',
      );
    } on UserProfileFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on AuthFailure catch (failure) {
      state = ProfileActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const ProfileActionState.failure(
        message: 'Não foi possível registrar o aceite. Tente novamente.',
      );
    }
  }

  Future<AuthVerificationSnapshot> _verifiedIdentity() async {
    final AuthVerificationSnapshot verification = await _authRepository
        .forceRefreshIdentityToken();
    if (!verification.isFullyVerified || verification.user == null) {
      throw const UserProfileFailure(
        kind: UserProfileFailureKind.unauthenticated,
        safeMessage: 'Atualize a confirmação do seu email antes de continuar.',
        code: 'token_not_verified',
      );
    }
    return verification;
  }
}
