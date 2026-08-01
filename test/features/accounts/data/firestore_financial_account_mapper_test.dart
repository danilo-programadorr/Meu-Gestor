import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firestore_financial_account_mapper.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';

void main() {
  group('FirestoreFinancialAccountMapper', () {
    test('converte documento válido sem duplicar ID nos campos', () {
      final FinancialAccount account = FirestoreFinancialAccountMapper.fromMap(
        data: _validMap(),
        documentId: 'document-id',
        expectedOwnerId: 'owner',
      );
      expect(account.id, 'document-id');
      expect(account.ownerId, 'owner');
      expect(account.openingBalanceCents, 123456);
      expect(_validMap(), isNot(contains('accountId')));
    });

    for (final String missingField in <String>[
      'ownerId',
      'name',
      'openingBalanceCents',
      'createdAt',
    ]) {
      test('rejeita campo ausente: $missingField', () {
        final Map<String, dynamic> data = _validMap()..remove(missingField);
        expect(
          () => FirestoreFinancialAccountMapper.fromMap(
            data: data,
            documentId: 'id',
            expectedOwnerId: 'owner',
          ),
          throwsA(isA<FinancialAccountFailure>()),
        );
      });
    }

    test('rejeita campo adicional', () {
      final Map<String, dynamic> data = _validMap()
        ..['currentBalanceCents'] = 1;
      expect(
        () => FirestoreFinancialAccountMapper.fromMap(
          data: data,
          documentId: 'id',
          expectedOwnerId: 'owner',
        ),
        throwsA(
          isA<FinancialAccountFailure>().having(
            (FinancialAccountFailure failure) => failure.kind,
            'kind',
            FinancialAccountFailureKind.incompatible,
          ),
        ),
      );
    });

    for (final MapEntry<String, Object> replacement in <String, Object>{
      'openingBalanceCents': 1.5,
      'includeInTotal': 'true',
      'createdAt': '01/08/2026',
    }.entries) {
      test('rejeita tipo incorreto em ${replacement.key}', () {
        final Map<String, dynamic> data = _validMap()
          ..[replacement.key] = replacement.value;
        expect(
          () => FirestoreFinancialAccountMapper.fromMap(
            data: data,
            documentId: 'id',
            expectedOwnerId: 'owner',
          ),
          throwsA(
            isA<FinancialAccountFailure>().having(
              (FinancialAccountFailure failure) => failure.kind,
              'kind',
              FinancialAccountFailureKind.conversion,
            ),
          ),
        );
      });
    }

    test('rejeita ownerId diferente do caminho', () {
      expect(
        () => FirestoreFinancialAccountMapper.fromMap(
          data: _validMap(),
          documentId: 'id',
          expectedOwnerId: 'other-owner',
        ),
        throwsA(isA<FinancialAccountFailure>()),
      );
    });

    test('rejeita tipo desconhecido', () {
      final Map<String, dynamic> data = _validMap()..['type'] = 'creditCard';
      expect(
        () => FirestoreFinancialAccountMapper.fromMap(
          data: data,
          documentId: 'id',
          expectedOwnerId: 'owner',
        ),
        throwsA(isA<FinancialAccountFailure>()),
      );
    });

    test('rejeita timestamp de servidor pendente', () {
      final Map<String, dynamic> data = _validMap()..['updatedAt'] = null;
      expect(
        () => FirestoreFinancialAccountMapper.fromMap(
          data: data,
          documentId: 'id',
          expectedOwnerId: 'owner',
        ),
        throwsA(isA<FinancialAccountFailure>()),
      );
    });

    test('rejeita par de arquivamento incoerente', () {
      final Map<String, dynamic> data = _validMap()
        ..['isArchived'] = true
        ..['archivedAt'] = null;
      expect(
        () => FirestoreFinancialAccountMapper.fromMap(
          data: data,
          documentId: 'id',
          expectedOwnerId: 'owner',
        ),
        throwsA(isA<FinancialAccountFailure>()),
      );
    });

    test('mapa de criação contém somente os onze campos autorizados', () {
      final Map<String, Object?> data =
          FirestoreFinancialAccountMapper.creationMap(
            ownerId: 'owner',
            draft: const FinancialAccountDraft(
              name: 'Conta principal',
              type: FinancialAccountType.checking,
              openingBalanceCents: 0,
              includeInTotal: true,
            ),
          );
      expect(data.keys.toSet(), FirestoreFinancialAccountMapper.fieldNames);
      expect(data['isArchived'], isFalse);
      expect(data['archivedAt'], isNull);
      expect(data['currencyCode'], 'BRL');
      expect(data['schemaVersion'], 1);
    });

    test('mapa editável contém apenas quatro campos e updatedAt', () {
      final Map<String, Object> data =
          FirestoreFinancialAccountMapper.editableMap(
            const FinancialAccountDraft(
              name: 'Conta principal',
              type: FinancialAccountType.savings,
              openingBalanceCents: -1,
              includeInTotal: false,
            ),
          );
      expect(data.keys.toSet(), <String>{
        'name',
        'type',
        'openingBalanceCents',
        'includeInTotal',
        'updatedAt',
      });
    });
  });
}

Map<String, dynamic> _validMap() {
  final Timestamp timestamp = Timestamp.fromDate(DateTime.utc(2026, 8, 1, 12));
  return <String, dynamic>{
    'ownerId': 'owner',
    'name': 'Conta principal',
    'type': 'checking',
    'openingBalanceCents': 123456,
    'currencyCode': 'BRL',
    'includeInTotal': true,
    'isArchived': false,
    'archivedAt': null,
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'schemaVersion': 1,
  };
}
