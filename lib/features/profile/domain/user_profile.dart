import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';

final class UserProfile {
  const UserProfile({
    required this.ownerId,
    required this.displayName,
    required this.locale,
    required this.currencyCode,
    required this.timeZone,
    required this.emailVerifiedSnapshot,
    required this.termsVersionAccepted,
    required this.termsAcceptedAt,
    required this.privacyVersionAccepted,
    required this.privacyAcceptedAt,
    required this.aiConsentEnabled,
    required this.aiConsentUpdatedAt,
    required this.analyticsConsentEnabled,
    required this.analyticsConsentUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  static const String supportedLocale = 'pt-BR';
  static const String supportedCurrencyCode = 'BRL';
  static const String supportedTimeZone = 'America/Sao_Paulo';
  static const int currentSchemaVersion = 1;

  final String ownerId;
  final String displayName;
  final String locale;
  final String currencyCode;
  final String timeZone;
  final bool emailVerifiedSnapshot;
  final String termsVersionAccepted;
  final DateTime termsAcceptedAt;
  final String privacyVersionAccepted;
  final DateTime privacyAcceptedAt;
  final bool aiConsentEnabled;
  final DateTime aiConsentUpdatedAt;
  final bool analyticsConsentEnabled;
  final DateTime analyticsConsentUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  bool get hasCurrentLegalVersions => LegalDocumentVersions.areCurrent(
    termsVersion: termsVersionAccepted,
    privacyVersion: privacyVersionAccepted,
  );

  UserProfile copyWith({
    String? displayName,
    bool? emailVerifiedSnapshot,
    String? termsVersionAccepted,
    DateTime? termsAcceptedAt,
    String? privacyVersionAccepted,
    DateTime? privacyAcceptedAt,
    bool? aiConsentEnabled,
    DateTime? aiConsentUpdatedAt,
    bool? analyticsConsentEnabled,
    DateTime? analyticsConsentUpdatedAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      ownerId: ownerId,
      displayName: displayName ?? this.displayName,
      locale: locale,
      currencyCode: currencyCode,
      timeZone: timeZone,
      emailVerifiedSnapshot:
          emailVerifiedSnapshot ?? this.emailVerifiedSnapshot,
      termsVersionAccepted: termsVersionAccepted ?? this.termsVersionAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      privacyVersionAccepted:
          privacyVersionAccepted ?? this.privacyVersionAccepted,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      aiConsentEnabled: aiConsentEnabled ?? this.aiConsentEnabled,
      aiConsentUpdatedAt: aiConsentUpdatedAt ?? this.aiConsentUpdatedAt,
      analyticsConsentEnabled:
          analyticsConsentEnabled ?? this.analyticsConsentEnabled,
      analyticsConsentUpdatedAt:
          analyticsConsentUpdatedAt ?? this.analyticsConsentUpdatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }
}

final class UserProfileCreation {
  const UserProfileCreation({
    required this.ownerId,
    required this.displayName,
    required this.aiConsentEnabled,
    required this.analyticsConsentEnabled,
  });

  final String ownerId;
  final String displayName;
  final bool aiConsentEnabled;
  final bool analyticsConsentEnabled;
}

final class UserProfileReadResult {
  const UserProfileReadResult({
    required this.profile,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final UserProfile? profile;
  final bool isFromServer;
  final bool hasPendingWrites;
}

final class UserProfileCreationResult {
  const UserProfileCreationResult({
    required this.profile,
    required this.wasCreated,
  });

  final UserProfile profile;
  final bool wasCreated;
}
