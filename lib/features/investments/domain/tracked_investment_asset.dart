import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

enum TrackedInvestmentAssetType {
  stock('Ação'),
  fii('Fundo imobiliário');

  const TrackedInvestmentAssetType(this.label);
  final String label;

  static TrackedInvestmentAssetType fromStorage(String value) =>
      TrackedInvestmentAssetType.values.firstWhere(
        (TrackedInvestmentAssetType type) => type.name == value,
        orElse: () => throw const FormatException('invalid_asset_type'),
      );
}

final class TrackedInvestmentAsset {
  const TrackedInvestmentAsset({
    required this.id,
    required this.ownerId,
    required this.portfolioId,
    required this.ticker,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.currentQuantityScaled,
    required this.lastOperationId,
    required this.lastOperationAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    required this.revision,
  });

  static const int currentSchemaVersion = 1;
  static const String supportedCurrencyCode = 'BRL';
  static final RegExp tickerPattern = RegExp(r'^[A-Z]{4}[0-9]{1,2}$');

  final String id;
  final String ownerId;
  final String portfolioId;
  final String ticker;
  final String name;
  final TrackedInvestmentAssetType type;
  final String currencyCode;
  final int currentQuantityScaled;
  final String? lastOperationId;
  final DateTime? lastOperationAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;

  static String normalizeTicker(String value) => value.trim().toUpperCase();

  static String requireTicker(String value) {
    final String normalized = normalizeTicker(value);
    if (!tickerPattern.hasMatch(normalized)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe um ticker válido, como PETR4 ou HGLG11.',
        code: 'invalid_investment_ticker',
      );
    }
    return normalized;
  }

  static String requireName(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty || normalized.length > 80) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe um nome de ativo com até 80 caracteres.',
        code: 'invalid_investment_asset_name',
      );
    }
    return normalized;
  }

  static String documentId({
    required String portfolioId,
    required String ticker,
  }) => '${portfolioId}__${requireTicker(ticker)}';

  static void validate(TrackedInvestmentAsset asset) {
    if (asset.id !=
            documentId(portfolioId: asset.portfolioId, ticker: asset.ticker) ||
        asset.ownerId.isEmpty ||
        requireName(asset.name) != asset.name ||
        asset.currencyCode != supportedCurrencyCode ||
        asset.currentQuantityScaled < 0 ||
        asset.currentQuantityScaled > InvestmentScale.maximumQuantityScaled ||
        asset.schemaVersion != currentSchemaVersion ||
        asset.revision < 1 ||
        (asset.lastOperationId == null) != (asset.lastOperationAt == null)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'Encontramos uma inconsistência neste ativo.',
        code: 'invalid_tracked_investment_asset',
      );
    }
  }
}

final class TrackedInvestmentAssetDraft {
  const TrackedInvestmentAssetDraft({
    required this.portfolioId,
    required this.ticker,
    required this.name,
    required this.type,
  });

  final String portfolioId;
  final String ticker;
  final String name;
  final TrackedInvestmentAssetType type;

  TrackedInvestmentAssetDraft normalized() {
    if (portfolioId.isEmpty || portfolioId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Escolha uma carteira válida.',
        code: 'invalid_investment_portfolio_reference',
      );
    }
    return TrackedInvestmentAssetDraft(
      portfolioId: portfolioId,
      ticker: TrackedInvestmentAsset.requireTicker(ticker),
      name: TrackedInvestmentAsset.requireName(name),
      type: type,
    );
  }
}
