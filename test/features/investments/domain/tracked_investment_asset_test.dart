import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 24, 12);

  test('schema 2 aceita ativo vazio e arquivado sem histórico', () {
    final TrackedInvestmentAsset asset = TrackedInvestmentAsset(
      id: 'portfolio-1__PETR4',
      ownerId: 'owner',
      portfolioId: 'portfolio-1',
      ticker: 'PETR4',
      name: 'Petrobras PN',
      type: TrackedInvestmentAssetType.stock,
      currencyCode: 'BRL',
      currentQuantityScaled: 0,
      lastOperationId: null,
      lastOperationAt: null,
      isArchived: true,
      archivedAt: now,
      hasHistory: false,
      createdAt: now,
      updatedAt: now,
      schemaVersion: TrackedInvestmentAsset.currentSchemaVersion,
      revision: 2,
    );

    expect(() => TrackedInvestmentAsset.validate(asset), returnsNormally);
  });

  test('documento legado é conservador e nunca pode parecer vazio', () {
    final TrackedInvestmentAsset asset = TrackedInvestmentAsset(
      id: 'portfolio-1__PETR4',
      ownerId: 'owner',
      portfolioId: 'portfolio-1',
      ticker: 'PETR4',
      name: 'Petrobras PN',
      type: TrackedInvestmentAssetType.stock,
      currencyCode: 'BRL',
      currentQuantityScaled: 0,
      lastOperationId: null,
      lastOperationAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: 1,
      revision: 1,
    );

    expect(asset.hasHistory, isTrue);
    expect(() => TrackedInvestmentAsset.validate(asset), returnsNormally);
  });

  test('atualização normaliza nome e mantém ticker fora do contrato', () {
    const TrackedInvestmentAssetUpdate update = TrackedInvestmentAssetUpdate(
      name: '  Petrobras   PN ',
      type: TrackedInvestmentAssetType.fii,
    );

    expect(update.normalized().name, 'Petrobras PN');
    expect(update.normalized().type, TrackedInvestmentAssetType.fii);
  });
}
