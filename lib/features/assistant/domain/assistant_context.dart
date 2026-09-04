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
  civilDate,
  safeLabel,
}

/// Período financeiro explícito: início incluso e fim exclusivo, sempre na
/// convenção civil de São Paulo. Instantes UTC ficam reservados à telemetria
/// técnica e à janela de leitura do servidor.
final class AssistantCivilPeriod {
  AssistantCivilPeriod({
    required this.startDate,
    required this.endDateExclusive,
    this.timeZone = AssistantFinancialContext.civilTimeZone,
  }) {
    final DateTime? start = _parseCivilDate(startDate);
    final DateTime? end = _parseCivilDate(endDateExclusive);
    if (timeZone != AssistantFinancialContext.civilTimeZone ||
        start == null ||
        end == null ||
        !end.isAfter(start)) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  final String timeZone;
  final String startDate;
  final String endDateExclusive;

  static DateTime? _parseCivilDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final List<String> parts = value.split('-');
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }
}

final class AssistantFactEvidence {
  AssistantFactEvidence({
    required this.alias,
    required this.source,
    required this.period,
  }) {
    if (!_safeIdentifier.hasMatch(alias)) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  static final RegExp _safeIdentifier = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
  final String alias;
  final AssistantContextSource source;
  final AssistantCivilPeriod period;
}

final class AssistantContextFact {
  AssistantContextFact({
    required this.evidenceId,
    required this.source,
    required this.kind,
    required this.value,
    required this.civilPeriod,
    required this.evidence,
  }) {
    if (!_safeIdentifier.hasMatch(evidenceId) ||
        value is double ||
        value is List ||
        value is Map ||
        !_matchesKind(kind, value) ||
        evidence.alias != evidenceId ||
        evidence.source != source ||
        evidence.period.timeZone != civilPeriod.timeZone ||
        evidence.period.startDate != civilPeriod.startDate ||
        evidence.period.endDateExclusive != civilPeriod.endDateExclusive ||
        (value is String && !AssistantContentSafety.isSafe(value as String))) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  static final RegExp _safeIdentifier = RegExp(r'^[a-z][a-z0-9_]{2,63}$');
  final String evidenceId;
  final AssistantContextSource source;
  final AssistantFactKind kind;
  final Object value;
  final AssistantCivilPeriod civilPeriod;
  final AssistantFactEvidence evidence;

  static bool _matchesKind(AssistantFactKind kind, Object value) =>
      switch (kind) {
        AssistantFactKind.moneyCentsBrl ||
        AssistantFactKind.integer ||
        AssistantFactKind.basisPoints => value is int,
        AssistantFactKind.booleanValue => value is bool,
        AssistantFactKind.utcInstant => value is DateTime && value.isUtc,
        AssistantFactKind.civilDate =>
          value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value),
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
    required this.civilPeriod,
    required this.technicalWindowStart,
    required this.technicalWindowEndExclusive,
    required this.facts,
    required this.missingSources,
    required this.isFromServer,
    required this.hasPendingWrites,
  }) {
    final Set<String> evidenceIds = facts
        .map((fact) => fact.evidenceId)
        .toSet();
    if (!generatedAt.isUtc ||
        !technicalWindowStart.isUtc ||
        !technicalWindowEndExclusive.isUtc ||
        !technicalWindowEndExclusive.isAfter(technicalWindowStart) ||
        generatedAt.isBefore(technicalWindowEndExclusive) ||
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
  final AssistantCivilPeriod civilPeriod;
  final DateTime technicalWindowStart;
  final DateTime technicalWindowEndExclusive;
  final List<AssistantContextFact> facts;
  final Set<AssistantContextSource> missingSources;
  final bool isFromServer;
  final bool hasPendingWrites;
}
