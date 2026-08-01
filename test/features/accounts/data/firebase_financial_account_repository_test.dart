import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firebase_financial_account_repository.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';

void main() {
  test('decodifica e ordena lista própria localmente por nome', () {
    final FinancialAccountsReadResult result =
        FirebaseFinancialAccountRepository.decodeQuerySnapshot(
          ownerId: 'owner',
          documents: <AccountDocumentData>[
            AccountDocumentData(id: '2', data: _validMap('Poupança')),
            AccountDocumentData(id: '1', data: _validMap('Conta principal')),
          ],
          isFromCache: false,
          hasPendingWrites: false,
        );
    expect(result.accounts.map((account) => account.name), <String>[
      'Conta principal',
      'Poupança',
    ]);
    expect(result.isFromServer, isTrue);
    expect(result.hasPendingWrites, isFalse);
  });

  test('marca resultado de cache sem usá-lo como confirmação', () {
    final FinancialAccountsReadResult result =
        FirebaseFinancialAccountRepository.decodeQuerySnapshot(
          ownerId: 'owner',
          documents: <AccountDocumentData>[],
          isFromCache: true,
          hasPendingWrites: true,
        );
    expect(result.isFromServer, isFalse);
    expect(result.hasPendingWrites, isTrue);
  });

  final Map<String, FinancialAccountFailureKind> mappedCodes =
      <String, FinancialAccountFailureKind>{
        'permission-denied': FinancialAccountFailureKind.permissionDenied,
        'unauthenticated': FinancialAccountFailureKind.unauthenticated,
        'unavailable': FinancialAccountFailureKind.unavailable,
        'deadline-exceeded': FinancialAccountFailureKind.timeout,
        'aborted': FinancialAccountFailureKind.aborted,
        'failed-precondition': FinancialAccountFailureKind.failedPrecondition,
        'not-found': FinancialAccountFailureKind.notFound,
        'already-exists': FinancialAccountFailureKind.alreadyExists,
        'data-loss': FinancialAccountFailureKind.dataLoss,
      };
  for (final MapEntry<String, FinancialAccountFailureKind> entry
      in mappedCodes.entries) {
    test('mapeia erro Firestore ${entry.key}', () {
      final FinancialAccountFailure failure =
          FirebaseFinancialAccountRepository.mapFailure(
            FirebaseException(plugin: 'cloud_firestore', code: entry.key),
          );
      expect(failure.kind, entry.value);
      expect(failure.toString(), isNot(contains('owner')));
    });
  }

  test('mapeia erro desconhecido sem conteúdo sensível', () {
    final FinancialAccountFailure failure =
        FirebaseFinancialAccountRepository.mapFailure(
          StateError('saldo e nome privados'),
        );
    expect(failure.kind, FinancialAccountFailureKind.unknown);
    expect(failure.safeMessage, isNot(contains('saldo e nome privados')));
  });
}

Map<String, dynamic> _validMap(String name) {
  final Timestamp timestamp = Timestamp.fromDate(DateTime.utc(2026, 8, 1, 12));
  return <String, dynamic>{
    'ownerId': 'owner',
    'name': name,
    'type': 'checking',
    'openingBalanceCents': 0,
    'currencyCode': 'BRL',
    'includeInTotal': true,
    'isArchived': false,
    'archivedAt': null,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'schemaVersion': 1,
  };
}
