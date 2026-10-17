import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

/// Identidade pública de um ativo retornada pelo catálogo administrado no
/// backend. Nenhum dado de carteira ou de usuário participa deste contrato.
final class InvestmentAssetDirectoryEntry {
  const InvestmentAssetDirectoryEntry({
    required this.ticker,
    required this.name,
    required this.type,
  });

  final String ticker;
  final String name;
  final TrackedInvestmentAssetType type;

  static InvestmentAssetDirectoryEntry fromMap(Map<Object?, Object?> value) {
    if (value.length != 3 ||
        value.keys.toSet().difference(<Object?>{
          'ticker',
          'name',
          'type',
        }).isNotEmpty) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'O catálogo de ativos retornou dados incompatíveis.',
        code: 'investment_asset_directory_invalid_entry',
      );
    }
    final Object? ticker = value['ticker'];
    final Object? name = value['name'];
    final Object? type = value['type'];
    if (ticker is! String || name is! String || type is! String) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'O catálogo de ativos retornou dados incompatíveis.',
        code: 'investment_asset_directory_invalid_entry',
      );
    }
    final TrackedInvestmentAssetType assetType = switch (type) {
      'stock' => TrackedInvestmentAssetType.stock,
      'fii' => TrackedInvestmentAssetType.fii,
      _ => throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'O catálogo de ativos retornou um tipo incompatível.',
        code: 'investment_asset_directory_invalid_type',
      ),
    };
    return InvestmentAssetDirectoryEntry(
      ticker: TrackedInvestmentAsset.requireTicker(ticker),
      name: TrackedInvestmentAsset.requireName(name),
      type: assetType,
    );
  }
}

abstract interface class InvestmentAssetDirectory {
  Future<List<InvestmentAssetDirectoryEntry>> search(String query);
}
