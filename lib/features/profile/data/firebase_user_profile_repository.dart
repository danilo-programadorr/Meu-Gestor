import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';
import 'package:meu_gestor_financeiro/features/profile/data/firestore_profile_mapper.dart';
import 'package:meu_gestor_financeiro/features/profile/data/profile_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_repository.dart';

final class FirebaseUserProfileRepository implements UserProfileRepository {
  FirebaseUserProfileRepository({
    required FirebaseFirestore firestore,
    required ProfileDiagnostics diagnostics,
  }) : _firestore = firestore,
       _diagnostics = diagnostics;

  final FirebaseFirestore _firestore;
  final ProfileDiagnostics _diagnostics;

  @override
  Future<UserProfileCreationResult> createIfAbsent(
    UserProfileCreation creation,
  ) async {
    final String displayName = DisplayName.requireValid(creation.displayName);
    final DocumentReference<Map<String, dynamic>> reference = _rawDocument(
      creation.ownerId,
    );
    try {
      final bool wasCreated = await _firestore.runTransaction<bool>((
        Transaction transaction,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        if (snapshot.exists) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null) {
            throw _incompatible('existing_profile_without_data');
          }
          FirestoreProfileMapper.fromMap(data, creation.ownerId);
          return false;
        }

        transaction.set(reference, <String, Object>{
          'ownerId': creation.ownerId,
          'displayName': displayName,
          'locale': UserProfile.supportedLocale,
          'currencyCode': UserProfile.supportedCurrencyCode,
          'timeZone': UserProfile.supportedTimeZone,
          'emailVerifiedSnapshot': true,
          'termsVersionAccepted': LegalDocumentVersions.terms,
          'termsAcceptedAt': FieldValue.serverTimestamp(),
          'privacyVersionAccepted': LegalDocumentVersions.privacy,
          'privacyAcceptedAt': FieldValue.serverTimestamp(),
          'aiConsentEnabled': creation.aiConsentEnabled,
          'aiConsentUpdatedAt': FieldValue.serverTimestamp(),
          'analyticsConsentEnabled': creation.analyticsConsentEnabled,
          'analyticsConsentUpdatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'schemaVersion': UserProfile.currentSchemaVersion,
        });
        return true;
      });

      final UserProfile profile = await _readConfirmedProfile(creation.ownerId);
      return UserProfileCreationResult(
        profile: profile,
        wasCreated: wasCreated,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'create_profile',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  @override
  Future<UserProfileReadResult> readOwnProfile({
    required String ownerId,
    required bool serverOnly,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _rawDocument(
            ownerId,
          ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      return decodeReadSnapshot(
        ownerId: ownerId,
        exists: snapshot.exists,
        data: snapshot.data(),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_profile',
        stage: serverOnly ? 'server_read' : 'default_read',
        error: error,
      );
    }
  }

  @visibleForTesting
  static UserProfileReadResult decodeReadSnapshot({
    required String ownerId,
    required bool exists,
    required Map<String, dynamic>? data,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    if (!exists) {
      return UserProfileReadResult(
        profile: null,
        isFromServer: !isFromCache,
        hasPendingWrites: hasPendingWrites,
      );
    }
    if (data == null) {
      throw _incompatible('existing_profile_without_data');
    }
    return UserProfileReadResult(
      profile: FirestoreProfileMapper.fromMap(data, ownerId),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  Future<UserProfile> updateDisplayName({
    required String ownerId,
    required String displayName,
  }) async {
    final String normalized = DisplayName.requireValid(displayName);
    return _update(
      ownerId: ownerId,
      operation: 'update_display_name',
      buildUpdates: (UserProfile current) => current.displayName == normalized
          ? <String, Object>{}
          : <String, Object>{'displayName': normalized},
    );
  }

  @override
  Future<UserProfile> updateOptionalConsents({
    required String ownerId,
    required bool aiConsentEnabled,
    required bool analyticsConsentEnabled,
  }) async {
    return _update(
      ownerId: ownerId,
      operation: 'update_optional_consents',
      buildUpdates: (UserProfile current) {
        final Map<String, Object> updates = <String, Object>{};
        if (current.aiConsentEnabled != aiConsentEnabled) {
          updates['aiConsentEnabled'] = aiConsentEnabled;
          updates['aiConsentUpdatedAt'] = FieldValue.serverTimestamp();
        }
        if (current.analyticsConsentEnabled != analyticsConsentEnabled) {
          updates['analyticsConsentEnabled'] = analyticsConsentEnabled;
          updates['analyticsConsentUpdatedAt'] = FieldValue.serverTimestamp();
        }
        return updates;
      },
    );
  }

  @override
  Future<UserProfile> acceptCurrentLegalVersions({
    required String ownerId,
  }) async {
    return _update(
      ownerId: ownerId,
      operation: 'accept_legal_versions',
      buildUpdates: (UserProfile current) {
        final Map<String, Object> updates = <String, Object>{};
        if (current.termsVersionAccepted != LegalDocumentVersions.terms) {
          updates['termsVersionAccepted'] = LegalDocumentVersions.terms;
          updates['termsAcceptedAt'] = FieldValue.serverTimestamp();
        }
        if (current.privacyVersionAccepted != LegalDocumentVersions.privacy) {
          updates['privacyVersionAccepted'] = LegalDocumentVersions.privacy;
          updates['privacyAcceptedAt'] = FieldValue.serverTimestamp();
        }
        return updates;
      },
    );
  }

  Future<UserProfile> _update({
    required String ownerId,
    required String operation,
    required Map<String, Object> Function(UserProfile current) buildUpdates,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _rawDocument(
      ownerId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        final Map<String, dynamic>? data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const UserProfileFailure(
            kind: UserProfileFailureKind.notFound,
            safeMessage: 'Seu perfil não foi encontrado.',
            code: 'profile_not_found',
          );
        }
        final UserProfile current = FirestoreProfileMapper.fromMap(
          data,
          ownerId,
        );
        final Map<String, Object> updates = buildUpdates(current);
        if (updates.isEmpty) {
          return;
        }
        updates['emailVerifiedSnapshot'] = true;
        updates['updatedAt'] = FieldValue.serverTimestamp();
        transaction.update(reference, updates);
      });
      return _readConfirmedProfile(ownerId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: operation,
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  Future<UserProfile> _readConfirmedProfile(String ownerId) async {
    final UserProfileReadResult result = await readOwnProfile(
      ownerId: ownerId,
      serverOnly: true,
    );
    final UserProfile? profile = result.profile;
    if (profile == null || !result.isFromServer || result.hasPendingWrites) {
      throw const UserProfileFailure(
        kind: UserProfileFailureKind.failedPrecondition,
        safeMessage:
            'A alteração ainda não foi confirmada. Verifique sua conexão e tente novamente.',
        code: 'profile_not_server_confirmed',
      );
    }
    return profile;
  }

  DocumentReference<Map<String, dynamic>> _rawDocument(String ownerId) {
    if (ownerId.isEmpty) {
      throw const UserProfileFailure(
        kind: UserProfileFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_owner_id',
      );
    }
    return _firestore.collection('users').doc(ownerId);
  }

  UserProfileFailure _mapAndRecord({
    required String operation,
    required String stage,
    required Object error,
  }) {
    final UserProfileFailure failure = _mapFailure(error);
    _diagnostics.record(
      operation: operation,
      category: failure.kind.name,
      stage: stage,
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  static UserProfileFailure _mapFailure(Object error) {
    if (error is UserProfileFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const UserProfileFailure(
          kind: UserProfileFailureKind.permissionDenied,
          safeMessage: 'Não foi possível acessar seu perfil com segurança.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const UserProfileFailure(
          kind: UserProfileFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const UserProfileFailure(
          kind: UserProfileFailureKind.unavailable,
          safeMessage:
              'Seu perfil está temporariamente indisponível. Tente novamente.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const UserProfileFailure(
          kind: UserProfileFailureKind.timeout,
          safeMessage: 'A operação demorou demais. Tente novamente.',
          code: 'deadline-exceeded',
        ),
        'aborted' => const UserProfileFailure(
          kind: UserProfileFailureKind.aborted,
          safeMessage:
              'O perfil foi atualizado em outro lugar. Tente novamente.',
          code: 'aborted',
        ),
        'failed-precondition' => const UserProfileFailure(
          kind: UserProfileFailureKind.failedPrecondition,
          safeMessage: 'Não foi possível confirmar a alteração com segurança.',
          code: 'failed-precondition',
        ),
        'not-found' => const UserProfileFailure(
          kind: UserProfileFailureKind.notFound,
          safeMessage: 'Seu perfil não foi encontrado.',
          code: 'not-found',
        ),
        'data-loss' => const UserProfileFailure(
          kind: UserProfileFailureKind.dataLoss,
          safeMessage:
              'Encontramos uma inconsistência no seu perfil. Nenhum dado foi alterado.',
          code: 'data-loss',
        ),
        _ => const UserProfileFailure(
          kind: UserProfileFailureKind.unknown,
          safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const UserProfileFailure(
      kind: UserProfileFailureKind.unknown,
      safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      code: 'unknown_profile_error',
    );
  }

  static UserProfileFailure _incompatible(String code) {
    return UserProfileFailure(
      kind: UserProfileFailureKind.incompatible,
      safeMessage:
          'Encontramos uma inconsistência no seu perfil. Nenhum dado foi alterado.',
      code: code,
    );
  }
}
