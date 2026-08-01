import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';

abstract final class FirestoreProfileMapper {
  static const Set<String> fieldNames = <String>{
    'ownerId',
    'displayName',
    'locale',
    'currencyCode',
    'timeZone',
    'emailVerifiedSnapshot',
    'termsVersionAccepted',
    'termsAcceptedAt',
    'privacyVersionAccepted',
    'privacyAcceptedAt',
    'aiConsentEnabled',
    'aiConsentUpdatedAt',
    'analyticsConsentEnabled',
    'analyticsConsentUpdatedAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };

  static UserProfile fromMap(Map<String, dynamic> data, String documentId) {
    try {
      if (data.keys.toSet().difference(fieldNames).isNotEmpty ||
          fieldNames.difference(data.keys.toSet()).isNotEmpty) {
        throw const UserProfileFailure(
          kind: UserProfileFailureKind.incompatible,
          safeMessage:
              'Encontramos uma inconsistência no seu perfil. Nenhum dado foi alterado.',
          code: 'unexpected_profile_fields',
        );
      }

      final String ownerId = _string(data, 'ownerId');
      final String displayName = _string(data, 'displayName');
      final String locale = _string(data, 'locale');
      final String currencyCode = _string(data, 'currencyCode');
      final String timeZone = _string(data, 'timeZone');
      final int schemaVersion = _integer(data, 'schemaVersion');

      if (ownerId != documentId ||
          DisplayName.validate(displayName) != null ||
          DisplayName.normalize(displayName) != displayName ||
          locale != UserProfile.supportedLocale ||
          currencyCode != UserProfile.supportedCurrencyCode ||
          timeZone != UserProfile.supportedTimeZone ||
          schemaVersion != UserProfile.currentSchemaVersion) {
        throw const UserProfileFailure(
          kind: UserProfileFailureKind.incompatible,
          safeMessage:
              'Encontramos uma inconsistência no seu perfil. Nenhum dado foi alterado.',
          code: 'invalid_profile_invariant',
        );
      }

      return UserProfile(
        ownerId: ownerId,
        displayName: displayName,
        locale: locale,
        currencyCode: currencyCode,
        timeZone: timeZone,
        emailVerifiedSnapshot: _boolean(data, 'emailVerifiedSnapshot'),
        termsVersionAccepted: _string(data, 'termsVersionAccepted'),
        termsAcceptedAt: _dateTime(data, 'termsAcceptedAt'),
        privacyVersionAccepted: _string(data, 'privacyVersionAccepted'),
        privacyAcceptedAt: _dateTime(data, 'privacyAcceptedAt'),
        aiConsentEnabled: _boolean(data, 'aiConsentEnabled'),
        aiConsentUpdatedAt: _dateTime(data, 'aiConsentUpdatedAt'),
        analyticsConsentEnabled: _boolean(data, 'analyticsConsentEnabled'),
        analyticsConsentUpdatedAt: _dateTime(data, 'analyticsConsentUpdatedAt'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: schemaVersion,
      );
    } on UserProfileFailure {
      rethrow;
    } on Object {
      throw const UserProfileFailure(
        kind: UserProfileFailureKind.conversion,
        safeMessage:
            'Encontramos uma inconsistência no seu perfil. Nenhum dado foi alterado.',
        code: 'profile_conversion_failed',
      );
    }
  }

  static Map<String, Object> toMap(UserProfile profile) {
    return <String, Object>{
      'ownerId': profile.ownerId,
      'displayName': profile.displayName,
      'locale': profile.locale,
      'currencyCode': profile.currencyCode,
      'timeZone': profile.timeZone,
      'emailVerifiedSnapshot': profile.emailVerifiedSnapshot,
      'termsVersionAccepted': profile.termsVersionAccepted,
      'termsAcceptedAt': Timestamp.fromDate(profile.termsAcceptedAt),
      'privacyVersionAccepted': profile.privacyVersionAccepted,
      'privacyAcceptedAt': Timestamp.fromDate(profile.privacyAcceptedAt),
      'aiConsentEnabled': profile.aiConsentEnabled,
      'aiConsentUpdatedAt': Timestamp.fromDate(profile.aiConsentUpdatedAt),
      'analyticsConsentEnabled': profile.analyticsConsentEnabled,
      'analyticsConsentUpdatedAt': Timestamp.fromDate(
        profile.analyticsConsentUpdatedAt,
      ),
      'createdAt': Timestamp.fromDate(profile.createdAt),
      'updatedAt': Timestamp.fromDate(profile.updatedAt),
      'schemaVersion': profile.schemaVersion,
    };
  }

  static bool _boolean(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! bool) {
      throw StateError('invalid_boolean');
    }
    return value;
  }

  static DateTime _dateTime(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! Timestamp) {
      throw StateError('invalid_or_pending_timestamp');
    }
    return value.toDate().toUtc();
  }

  static int _integer(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! int) {
      throw StateError('invalid_integer');
    }
    return value;
  }

  static String _string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String) {
      throw StateError('invalid_string');
    }
    return value;
  }
}
