import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/profile/data/firestore_profile_mapper.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';

void main() {
  group('FirestoreProfileMapper', () {
    test('converte perfil válido com timestamps', () {
      final profile = FirestoreProfileMapper.fromMap(_validMap(), 'test-owner');

      expect(profile.ownerId, 'test-owner');
      expect(profile.displayName, 'Pessoa Teste');
      expect(profile.createdAt, DateTime.utc(2026, 7, 31, 12));
      expect(profile.schemaVersion, 1);
    });

    test('rejeita campo obrigatório ausente', () {
      final Map<String, dynamic> data = _validMap()..remove('displayName');

      expect(
        () => FirestoreProfileMapper.fromMap(data, 'test-owner'),
        throwsA(isA<UserProfileFailure>()),
      );
    });

    test('rejeita campo adicional', () {
      final Map<String, dynamic> data = _validMap()..['email'] = 'omitido';

      expect(
        () => FirestoreProfileMapper.fromMap(data, 'test-owner'),
        throwsA(isA<UserProfileFailure>()),
      );
    });

    test('rejeita tipo de campo inválido', () {
      final Map<String, dynamic> data = _validMap()..['schemaVersion'] = '1';

      expect(
        () => FirestoreProfileMapper.fromMap(data, 'test-owner'),
        throwsA(
          isA<UserProfileFailure>().having(
            (failure) => failure.kind,
            'kind',
            UserProfileFailureKind.conversion,
          ),
        ),
      );
    });

    test('rejeita schemaVersion incompatível', () {
      final Map<String, dynamic> data = _validMap()..['schemaVersion'] = 2;

      expect(
        () => FirestoreProfileMapper.fromMap(data, 'test-owner'),
        throwsA(
          isA<UserProfileFailure>().having(
            (failure) => failure.kind,
            'kind',
            UserProfileFailureKind.incompatible,
          ),
        ),
      );
    });

    test('rejeita ownerId diferente do caminho', () {
      expect(
        () => FirestoreProfileMapper.fromMap(_validMap(), 'other-owner'),
        throwsA(isA<UserProfileFailure>()),
      );
    });

    test('não entrega domínio com timestamp de servidor pendente', () {
      final Map<String, dynamic> data = _validMap()..['updatedAt'] = null;

      expect(
        () => FirestoreProfileMapper.fromMap(data, 'test-owner'),
        throwsA(
          isA<UserProfileFailure>().having(
            (failure) => failure.kind,
            'kind',
            UserProfileFailureKind.conversion,
          ),
        ),
      );
    });
  });
}

Map<String, dynamic> _validMap() {
  final Timestamp timestamp = Timestamp.fromDate(DateTime.utc(2026, 7, 31, 12));
  return <String, dynamic>{
    'ownerId': 'test-owner',
    'displayName': 'Pessoa Teste',
    'locale': 'pt-BR',
    'currencyCode': 'BRL',
    'timeZone': 'America/Sao_Paulo',
    'emailVerifiedSnapshot': true,
    'termsVersionAccepted': 'terms-dev-1.0.0',
    'termsAcceptedAt': timestamp,
    'privacyVersionAccepted': 'privacy-dev-1.0.0',
    'privacyAcceptedAt': timestamp,
    'aiConsentEnabled': false,
    'aiConsentUpdatedAt': timestamp,
    'analyticsConsentEnabled': false,
    'analyticsConsentUpdatedAt': timestamp,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'schemaVersion': 1,
  };
}
