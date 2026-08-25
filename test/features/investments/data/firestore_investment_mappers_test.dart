import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firestore_investment_mappers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  final Timestamp time = Timestamp.fromDate(DateTime.utc(2026, 8, 1, 3));

  test('mapper de carteira exige campos exatos e proprietário esperado', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'ownerId': 'owner',
      'name': 'Longo prazo',
      'description': '',
      'isArchived': false,
      'archivedAt': null,
      'createdAt': time,
      'updatedAt': time,
      'schemaVersion': 1,
      'revision': 1,
    };
    final InvestmentPortfolio legacy =
        FirestoreInvestmentPortfolioMapper.fromMap(
          data: data,
          documentId: 'portfolio-1',
          expectedOwnerId: 'owner',
        );
    expect(legacy.name, 'Longo prazo');
    expect(legacy.hasHistory, isTrue);
    expect(
      () => FirestoreInvestmentPortfolioMapper.fromMap(
        data: <String, dynamic>{...data, 'extra': true},
        documentId: 'portfolio-1',
        expectedOwnerId: 'owner',
      ),
      throwsException,
    );
  });

  test('mapper de carteira schema 2 exige marcador de histórico estrito', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'ownerId': 'owner',
      'name': 'Sem histórico',
      'description': '',
      'isArchived': false,
      'archivedAt': null,
      'hasHistory': false,
      'createdAt': time,
      'updatedAt': time,
      'schemaVersion': InvestmentPortfolio.currentSchemaVersion,
      'revision': 1,
    };
    expect(
      FirestoreInvestmentPortfolioMapper.fromMap(
        data: data,
        documentId: 'portfolio-2',
        expectedOwnerId: 'owner',
      ).hasHistory,
      isFalse,
    );
    expect(
      () => FirestoreInvestmentPortfolioMapper.fromMap(
        data: <String, dynamic>{...data}..remove('hasHistory'),
        documentId: 'portfolio-2',
        expectedOwnerId: 'owner',
      ),
      throwsException,
    );
  });

  test('mapper de ativo valida id determinístico e tipos', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'ownerId': 'owner',
      'portfolioId': 'portfolio-1',
      'ticker': 'HGLG11',
      'name': 'CSHG Logística',
      'assetType': 'fii',
      'currencyCode': 'BRL',
      'currentQuantityScaled': 0,
      'lastOperationId': null,
      'lastOperationAt': null,
      'createdAt': time,
      'updatedAt': time,
      'schemaVersion': 1,
      'revision': 1,
    };
    final TrackedInvestmentAsset asset =
        FirestoreTrackedInvestmentAssetMapper.fromMap(
          data: data,
          documentId: 'portfolio-1__HGLG11',
          expectedOwnerId: 'owner',
        );
    expect(asset.type, TrackedInvestmentAssetType.fii);
    expect(
      () => FirestoreTrackedInvestmentAssetMapper.fromMap(
        data: data,
        documentId: 'outro-id',
        expectedOwnerId: 'owner',
      ),
      throwsException,
    );
  });

  test(
    'mapper de ativo schema 2 trata histórico e arquivamento estritamente',
    () {
      final Map<String, dynamic> data = <String, dynamic>{
        'ownerId': 'owner',
        'portfolioId': 'portfolio-1',
        'ticker': 'PETR4',
        'name': 'Petrobras PN',
        'assetType': 'stock',
        'currencyCode': 'BRL',
        'currentQuantityScaled': 0,
        'lastOperationId': null,
        'lastOperationAt': null,
        'isArchived': true,
        'archivedAt': time,
        'hasHistory': false,
        'createdAt': time,
        'updatedAt': time,
        'schemaVersion': TrackedInvestmentAsset.currentSchemaVersion,
        'revision': 2,
      };
      final TrackedInvestmentAsset asset =
          FirestoreTrackedInvestmentAssetMapper.fromMap(
            data: data,
            documentId: 'portfolio-1__PETR4',
            expectedOwnerId: 'owner',
          );
      expect(asset.isArchived, isTrue);
      expect(asset.hasHistory, isFalse);
      expect(
        () => FirestoreTrackedInvestmentAssetMapper.fromMap(
          data: <String, dynamic>{...data}..remove('hasHistory'),
          documentId: 'portfolio-1__PETR4',
          expectedOwnerId: 'owner',
        ),
        throwsException,
      );
    },
  );

  test('mapper de operação preserva cadeia anterior e inteiros escalados', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'ownerId': 'owner',
      'portfolioId': 'portfolio-1',
      'assetId': 'portfolio-1__PETR4',
      'previousOperationId': 'op-0',
      'previousOperationAt': time,
      'kind': 'buy',
      'occurredAt': time,
      'quantityScaled': 100000000,
      'unitPriceScaled': 32000000,
      'feesCents': 25,
      'notes': '',
      'isVoided': false,
      'voidedAt': null,
      'mutationId': 'op-1',
      'createdAt': time,
      'updatedAt': time,
      'schemaVersion': 1,
      'revision': 1,
    };
    final InvestmentOperation operation =
        FirestoreInvestmentOperationMapper.fromMap(
          data: data,
          documentId: 'op-1',
          expectedOwnerId: 'owner',
          now: DateTime.utc(2026, 8, 2),
        );
    expect(operation.previousOperationId, 'op-0');
    expect(operation.grossAmountCents, 3200);
    expect(
      () => FirestoreInvestmentOperationMapper.fromMap(
        data: <String, dynamic>{...data}..remove('feesCents'),
        documentId: 'op-1',
        expectedOwnerId: 'owner',
        now: DateTime.utc(2026, 8, 2),
      ),
      throwsException,
    );
  });

  test('mapas de criação não persistem projeções monetárias derivadas', () {
    final Map<String, Object?> map =
        FirestoreInvestmentOperationMapper.creationMap(
          ownerId: 'owner',
          operationId: 'op-1',
          draft: InvestmentOperationDraft(
            portfolioId: 'portfolio-1',
            assetId: 'portfolio-1__PETR4',
            kind: InvestmentOperationKind.buy,
            occurredAt: DateTime.utc(2026, 8, 1, 3),
            quantityScaled: 100000000,
            unitPriceScaled: 32000000,
            feesCents: 0,
            notes: '',
          ),
          previousOperationId: null,
          previousOperationAt: null,
        );
    expect(map.keys, FirestoreInvestmentOperationMapper.fieldNames);
    expect(map, isNot(contains('grossAmountCents')));
  });

  test('rascunhos normalizam carteira, ticker e nome', () {
    final Map<String, Object?> portfolioMap =
        FirestoreInvestmentPortfolioMapper.creationMap(
          ownerId: 'owner',
          draft: const InvestmentPortfolioDraft(
            name: '  Longo   prazo ',
            description: '  Manual ',
          ),
        );
    expect(portfolioMap['name'], 'Longo prazo');
    expect(portfolioMap['hasHistory'], isFalse);
    expect(
      portfolioMap['schemaVersion'],
      InvestmentPortfolio.currentSchemaVersion,
    );
    final Map<String, Object?> assetMap =
        FirestoreTrackedInvestmentAssetMapper.creationMap(
          ownerId: 'owner',
          draft: const TrackedInvestmentAssetDraft(
            portfolioId: 'portfolio-1',
            ticker: 'petr4',
            name: ' Petrobras   PN ',
            type: TrackedInvestmentAssetType.stock,
          ),
        );
    expect(assetMap['ticker'], 'PETR4');
    expect(
      assetMap['schemaVersion'],
      TrackedInvestmentAsset.currentSchemaVersion,
    );
    expect(assetMap['hasHistory'], isFalse);
    expect(assetMap['isArchived'], isFalse);
    expect(assetMap['archivedAt'], isNull);
  });
}
