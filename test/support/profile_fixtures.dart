import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';

UserProfile createTestProfile({
  String ownerId = 'test-owner',
  String displayName = 'Pessoa Teste',
  String termsVersion = LegalDocumentVersions.terms,
  String privacyVersion = LegalDocumentVersions.privacy,
  bool aiConsentEnabled = false,
  bool analyticsConsentEnabled = false,
}) {
  final DateTime timestamp = DateTime.utc(2026, 7, 31, 12);
  return UserProfile(
    ownerId: ownerId,
    displayName: displayName,
    locale: UserProfile.supportedLocale,
    currencyCode: UserProfile.supportedCurrencyCode,
    timeZone: UserProfile.supportedTimeZone,
    emailVerifiedSnapshot: true,
    termsVersionAccepted: termsVersion,
    termsAcceptedAt: timestamp,
    privacyVersionAccepted: privacyVersion,
    privacyAcceptedAt: timestamp,
    aiConsentEnabled: aiConsentEnabled,
    aiConsentUpdatedAt: timestamp,
    analyticsConsentEnabled: analyticsConsentEnabled,
    analyticsConsentUpdatedAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
    schemaVersion: UserProfile.currentSchemaVersion,
  );
}
