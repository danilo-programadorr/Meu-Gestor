import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String ownerSource = _readOwnerSource();
  final String repositorySource = File(
    'lib/features/owner_access/data/firebase_master_access_repository.dart',
  ).readAsStringSync();
  final String rules = File('firestore.rules').readAsStringSync();

  test('51. não existe e-mail hardcoded', () {
    final RegExp addressPattern = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    );
    expect(addressPattern.hasMatch(ownerSource), isFalse);
  });

  test('52. não existe UID hardcoded', () {
    expect(ownerSource, isNot(contains('test-user-')));
    expect(ownerSource, isNot(contains('OWNER_UID')));
    expect(ownerSource, isNot(contains('ownerUid =')));
  });

  test('53. não existe senha mestre', () {
    expect(ownerSource.toLowerCase(), isNot(contains('masterpassword')));
    expect(ownerSource.toLowerCase(), isNot(contains('senha mestre')));
    expect(ownerSource.toLowerCase(), isNot(contains('código de desbloqueio')));
  });

  test('54. rota não é liberada por parâmetro', () {
    expect(ownerSource, isNot(contains('/proprietario:')));
    expect(ownerSource, isNot(contains('queryParameters')));
  });

  test('55. cliente não cria administrador', () {
    expect(repositorySource, isNot(contains('.set(')));
    expect(repositorySource, isNot(contains('.add(')));
    expect(repositorySource, isNot(contains('.create(')));
  });

  test('56. cliente não edita nem exclui administrador', () {
    expect(repositorySource, isNot(contains('.update(')));
    expect(repositorySource, isNot(contains('.delete(')));
  });

  test('57. cliente não lista administradores', () {
    expect(repositorySource, isNot(contains('.snapshots(')));
    expect(repositorySource, contains('.doc(userId)'));
    expect(repositorySource, contains('Source.server'));
  });

  test('58. regras anteriores permanecem presentes', () {
    expect(rules, contains('match /users/{userId}'));
    expect(rules, contains('match /accounts/{accountId}'));
    expect(rules, contains('match /categories/{categoryId}'));
    expect(rules, contains('match /transactions/{transactionId}'));
    expect(rules, contains('isValidTransactionVoid'));
  });

  test('59. dados de outros UID permanecem negados', () {
    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains('request.auth.uid == adminUid'));
    expect(rules, contains('allow read, write: if false;'));
  });

  test('60. produção continua bloqueada', () {
    expect(ownerSource, contains('AppEnvironment.development'));
    expect(ownerSource, contains("supportedEnvironment = 'development'"));
    expect(rules, contains(".data.environment == 'development'"));
  });
}

String _readOwnerSource() {
  final StringBuffer result = StringBuffer();
  final Directory directory = Directory('lib/features/owner_access');
  final List<File> files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((File first, File second) => first.path.compareTo(second.path));
  for (final File file in files) {
    result.writeln(file.readAsStringSync());
  }
  return result.toString();
}
