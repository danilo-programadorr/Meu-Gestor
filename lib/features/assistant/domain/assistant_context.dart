import 'assistant_failure.dart';

enum AssistantContextAvailability {
  available,
  derived,
  globalReference,
  futureUnavailable,
}

enum AssistantContextSource {
  profileConfiguration,
  accounts,
  categories,
  transactions,
  payables,
  receivables,
  financialCalendar,
  investmentPortfolios,
  investmentAssets,
  investmentOperations,
  investmentIncome,
  delayedMarketQuotes,
  dashboardSummary,
  investmentPerformance,
  debtsAndInterest,
  budgets,
  goalsAndEmergencyReserve,
  projectedBalance,
  historicalTrends,
}

final class AssistantContextSourcePolicy {
  const AssistantContextSourcePolicy({
    required this.source,
    required this.availability,
    required this.containsOwnData,
  });

  final AssistantContextSource source;
  final AssistantContextAvailability availability;
  final bool containsOwnData;
}

abstract final class AssistantContextCatalog {
  static const List<AssistantContextSourcePolicy> policies = [
    AssistantContextSourcePolicy(
      source: AssistantContextSource.profileConfiguration,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.accounts,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.categories,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.transactions,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.payables,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.receivables,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.financialCalendar,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.investmentPortfolios,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.investmentAssets,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.investmentOperations,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.investmentIncome,
      availability: AssistantContextAvailability.available,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.delayedMarketQuotes,
      availability: AssistantContextAvailability.globalReference,
      containsOwnData: false,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.dashboardSummary,
      availability: AssistantContextAvailability.derived,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.investmentPerformance,
      availability: AssistantContextAvailability.derived,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.debtsAndInterest,
      availability: AssistantContextAvailability.futureUnavailable,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.budgets,
      availability: AssistantContextAvailability.futureUnavailable,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.goalsAndEmergencyReserve,
      availability: AssistantContextAvailability.futureUnavailable,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.projectedBalance,
      availability: AssistantContextAvailability.futureUnavailable,
      containsOwnData: true,
    ),
    AssistantContextSourcePolicy(
      source: AssistantContextSource.historicalTrends,
      availability: AssistantContextAvailability.futureUnavailable,
      containsOwnData: true,
    ),
  ];

  static const Set<String> forbiddenProviderFields = {
    'uid',
    'ownerId',
    'email',
    'displayName',
    'token',
    'password',
    'apiKey',
    'secret',
    'credential',
    'appId',
    'projectId',
    'deviceId',
    'ipAddress',
    'mutationId',
    'externalId',
  };
}

enum AssistantFactKind {
  moneyCentsBrl,
  integer,
  basisPoints,
  booleanValue,
  utcInstant,
  safeLabel,
}

final class AssistantContextFact {
  AssistantContextFact({
    required this.evidenceId,
    required this.source,
    required this.kind,
    required this.value,
  }) {
    if (!_safeIdentifier.hasMatch(evidenceId) ||
        value is double ||
        value is List ||
        value is Map ||
        !_matchesKind(kind, value) ||
        (value is String && !AssistantContentSafety.isSafe(value as String))) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  static final RegExp _safeIdentifier = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
  final String evidenceId;
  final AssistantContextSource source;
  final AssistantFactKind kind;
  final Object value;

  static bool _matchesKind(AssistantFactKind kind, Object value) =>
      switch (kind) {
        AssistantFactKind.moneyCentsBrl ||
        AssistantFactKind.integer ||
        AssistantFactKind.basisPoints => value is int,
        AssistantFactKind.booleanValue => value is bool,
        AssistantFactKind.utcInstant => value is DateTime && value.isUtc,
        AssistantFactKind.safeLabel =>
          value is String && value.trim().isNotEmpty && value.length <= 80,
      };
}

abstract final class AssistantContentSafety {
  static final RegExp _email = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _longIdentifier = RegExp(
    r'(?<!\d)(?:\d[ .-]?){11,19}(?!\d)',
  );
  static final RegExp _secret = RegExp(
    r'(?:bearer\s+|api[_ -]?key|private[_ -]?key|password|senha|token\s*[:=])',
    caseSensitive: false,
  );

  static bool isSafe(String value) {
    final String normalized = value.trim();
    return normalized.isNotEmpty &&
        normalized.length <= 2000 &&
        !_email.hasMatch(normalized) &&
        !_longIdentifier.hasMatch(normalized) &&
        !_secret.hasMatch(normalized);
  }
}

/// Contexto estruturado e minimizado. O servidor cria aliases efêmeros de
/// evidência; IDs persistidos jamais atravessam a fronteira do provedor.
final class AssistantFinancialContext {
  AssistantFinancialContext({
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.facts,
    required this.missingSources,
    required this.isFromServer,
    required this.hasPendingWrites,
  }) {
    final Set<String> evidenceIds = facts
        .map((fact) => fact.evidenceId)
        .toSet();
    if (!generatedAt.isUtc ||
        !periodStart.isUtc ||
        !periodEnd.isUtc ||
        periodEnd.isBefore(periodStart) ||
        generatedAt.isBefore(periodEnd) ||
        evidenceIds.length != facts.length ||
        !isFromServer ||
        hasPendingWrites) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  static const int schemaVersion = 1;
  static const String locale = 'pt-BR';
  static const String currency = 'BRL';
  static const String civilTimeZone = 'America/Sao_Paulo';
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<AssistantContextFact> facts;
  final Set<AssistantContextSource> missingSources;
  final bool isFromServer;
  final bool hasPendingWrites;
}
