import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfileReadResult> readOwnProfile({
    required String ownerId,
    required bool serverOnly,
  });

  Future<UserProfileCreationResult> createIfAbsent(
    UserProfileCreation creation,
  );

  Future<UserProfile> updateDisplayName({
    required String ownerId,
    required String displayName,
  });

  Future<UserProfile> updateOptionalConsents({
    required String ownerId,
    required bool aiConsentEnabled,
    required bool analyticsConsentEnabled,
  });

  Future<UserProfile> acceptCurrentLegalVersions({required String ownerId});
}
