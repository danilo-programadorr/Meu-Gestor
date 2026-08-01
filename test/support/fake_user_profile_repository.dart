import 'dart:async';

import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_repository.dart';

final class FakeUserProfileRepository implements UserProfileRepository {
  FakeUserProfileRepository({UserProfile? initialProfile})
    : profile = initialProfile;

  UserProfile? profile;
  UserProfileFailure? nextFailure;
  Completer<void>? createBarrier;
  Completer<void>? readBarrier;
  bool serverConfirmed = true;
  bool pendingWrites = false;
  int readCalls = 0;
  int createCalls = 0;
  int updateNameCalls = 0;
  int updateConsentsCalls = 0;
  int acceptLegalCalls = 0;

  @override
  Future<UserProfileCreationResult> createIfAbsent(
    UserProfileCreation creation,
  ) async {
    createCalls += 1;
    final Completer<void>? barrier = createBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    _throwIfNeeded();
    final UserProfile? existing = profile;
    if (existing != null) {
      return UserProfileCreationResult(profile: existing, wasCreated: false);
    }
    final DateTime now = DateTime.utc(2026, 7, 31, 12);
    final UserProfile created = UserProfile(
      ownerId: creation.ownerId,
      displayName: DisplayName.requireValid(creation.displayName),
      locale: UserProfile.supportedLocale,
      currencyCode: UserProfile.supportedCurrencyCode,
      timeZone: UserProfile.supportedTimeZone,
      emailVerifiedSnapshot: true,
      termsVersionAccepted: LegalDocumentVersions.terms,
      termsAcceptedAt: now,
      privacyVersionAccepted: LegalDocumentVersions.privacy,
      privacyAcceptedAt: now,
      aiConsentEnabled: creation.aiConsentEnabled,
      aiConsentUpdatedAt: now,
      analyticsConsentEnabled: creation.analyticsConsentEnabled,
      analyticsConsentUpdatedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: UserProfile.currentSchemaVersion,
    );
    profile = created;
    return UserProfileCreationResult(profile: created, wasCreated: true);
  }

  @override
  Future<UserProfileReadResult> readOwnProfile({
    required String ownerId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    final Completer<void>? barrier = readBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    _throwIfNeeded();
    return UserProfileReadResult(
      profile: profile,
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<UserProfile> updateDisplayName({
    required String ownerId,
    required String displayName,
  }) async {
    updateNameCalls += 1;
    _throwIfNeeded();
    final UserProfile current = _requireProfile();
    final UserProfile updated = current.copyWith(
      displayName: DisplayName.requireValid(displayName),
      updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    );
    profile = updated;
    return updated;
  }

  @override
  Future<UserProfile> updateOptionalConsents({
    required String ownerId,
    required bool aiConsentEnabled,
    required bool analyticsConsentEnabled,
  }) async {
    updateConsentsCalls += 1;
    _throwIfNeeded();
    final UserProfile current = _requireProfile();
    final DateTime now = current.updatedAt.add(const Duration(seconds: 1));
    final UserProfile updated = current.copyWith(
      aiConsentEnabled: aiConsentEnabled,
      aiConsentUpdatedAt: current.aiConsentEnabled == aiConsentEnabled
          ? current.aiConsentUpdatedAt
          : now,
      analyticsConsentEnabled: analyticsConsentEnabled,
      analyticsConsentUpdatedAt:
          current.analyticsConsentEnabled == analyticsConsentEnabled
          ? current.analyticsConsentUpdatedAt
          : now,
      updatedAt: now,
    );
    profile = updated;
    return updated;
  }

  @override
  Future<UserProfile> acceptCurrentLegalVersions({
    required String ownerId,
  }) async {
    acceptLegalCalls += 1;
    _throwIfNeeded();
    final UserProfile current = _requireProfile();
    final DateTime now = current.updatedAt.add(const Duration(seconds: 1));
    final UserProfile updated = current.copyWith(
      termsVersionAccepted: LegalDocumentVersions.terms,
      termsAcceptedAt:
          current.termsVersionAccepted == LegalDocumentVersions.terms
          ? current.termsAcceptedAt
          : now,
      privacyVersionAccepted: LegalDocumentVersions.privacy,
      privacyAcceptedAt:
          current.privacyVersionAccepted == LegalDocumentVersions.privacy
          ? current.privacyAcceptedAt
          : now,
      updatedAt: now,
    );
    profile = updated;
    return updated;
  }

  UserProfile _requireProfile() {
    final UserProfile? current = profile;
    if (current == null) {
      throw const UserProfileFailure(
        kind: UserProfileFailureKind.notFound,
        safeMessage: 'Seu perfil não foi encontrado.',
      );
    }
    return current;
  }

  void _throwIfNeeded() {
    final UserProfileFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }
}
