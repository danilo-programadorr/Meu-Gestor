import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';

final class InvestmentPortfolio {
  const InvestmentPortfolio({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.isArchived,
    required this.archivedAt,
    this.hasHistory = true,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    required this.revision,
  });

  static const int currentSchemaVersion = 2;
  static const int maximumNameLength = 60;
  static const int maximumDescriptionLength = 160;

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final bool isArchived;
  final DateTime? archivedAt;
  final bool hasHistory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;

  static String normalizeName(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty || normalized.length > maximumNameLength) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe um nome de carteira com até 60 caracteres.',
        code: 'invalid_investment_portfolio_name',
      );
    }
    return normalized;
  }

  static String normalizeDescription(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length > maximumDescriptionLength) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'A descrição deve ter no máximo 160 caracteres.',
        code: 'invalid_investment_portfolio_description',
      );
    }
    return normalized;
  }

  static void validate(InvestmentPortfolio portfolio) {
    if (portfolio.id.isEmpty ||
        portfolio.ownerId.isEmpty ||
        normalizeName(portfolio.name) != portfolio.name ||
        normalizeDescription(portfolio.description) != portfolio.description ||
        portfolio.isArchived != (portfolio.archivedAt != null) ||
        !<int>{1, currentSchemaVersion}.contains(portfolio.schemaVersion) ||
        (portfolio.schemaVersion == 1 && !portfolio.hasHistory) ||
        portfolio.revision < 1) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'Encontramos uma inconsistência nesta carteira.',
        code: 'invalid_investment_portfolio',
      );
    }
  }
}

final class InvestmentPortfolioDraft {
  const InvestmentPortfolioDraft({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  InvestmentPortfolioDraft normalized() => InvestmentPortfolioDraft(
    name: InvestmentPortfolio.normalizeName(name),
    description: InvestmentPortfolio.normalizeDescription(description),
  );
}
