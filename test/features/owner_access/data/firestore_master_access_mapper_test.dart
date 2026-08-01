import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/firebase_master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/firestore_master_access_mapper.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';

void main() {
  test('1. documento owner válido', () {
    final access = FirestoreMasterAccessMapper.fromMap(_validDocument());
    expect(access.role, AppRole.owner);
    expect(access.isActiveOwner, isTrue);
  });

  test('2. active false é documento válido e revogado', () {
    final access = FirestoreMasterAccessMapper.fromMap(
      _validDocument()..['active'] = false,
    );
    expect(access.active, isFalse);
    expect(access.isActiveOwner, isFalse);
  });

  test('3. role desconhecida é rejeitada', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..['role'] = 'administrator',
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('4. environment diferente é rejeitado', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..['environment'] = 'production',
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('5. schemaVersion inválida é rejeitada', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..['schemaVersion'] = 2,
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('6. grantedAt ausente é rejeitado', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..remove('grantedAt'),
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('7. grantedAt com tipo inválido é rejeitado', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..['grantedAt'] = '01/08/2026',
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('8. campo extra é rejeitado', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..['email'] = 'not-used@example.invalid',
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('9. campo obrigatório ausente é rejeitado', () {
    expect(
      () => FirestoreMasterAccessMapper.fromMap(
        _validDocument()..remove('active'),
      ),
      throwsA(isA<MasterAccessFailure>()),
    );
  });

  test('10. documento inexistente representa usuário comum', () {
    final MasterAccessReadResult result =
        FirebaseMasterAccessRepository.decodeReadSnapshot(
          exists: false,
          data: null,
          isFromCache: false,
          hasPendingWrites: false,
        );
    expect(result.decision, MasterAccessDecision.regularUser);
    expect(result.access, isNull);
  });
}

Map<String, dynamic> _validDocument() => <String, dynamic>{
  'role': 'owner',
  'active': true,
  'environment': 'development',
  'grantedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
  'schemaVersion': 1,
};
