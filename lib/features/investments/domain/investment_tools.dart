/// Ferramentas locais de apoio. Todos os valores monetários são centavos e
/// percentuais são pontos-base (100 = 1%). Nenhum resultado é recomendação.
abstract final class InvestmentTools {
  static const int _rateScale = 10000;

  static InvestmentProjection firstMillion({
    required int initialCents,
    required int monthlyContributionCents,
    required int monthlyRateBasisPoints,
    int targetCents = 100000000,
    int maximumMonths = 1200,
  }) {
    _nonNegative(initialCents, 'initialCents');
    _nonNegative(monthlyContributionCents, 'monthlyContributionCents');
    _nonNegative(monthlyRateBasisPoints, 'monthlyRateBasisPoints');
    _positive(targetCents, 'targetCents');
    _positive(maximumMonths, 'maximumMonths');
    var balance = initialCents;
    for (var month = 0; month <= maximumMonths; month++) {
      if (balance >= targetCents) {
        return InvestmentProjection(amountCents: balance, periods: month);
      }
      balance += _multiplyDivide(balance, monthlyRateBasisPoints, _rateScale);
      balance += monthlyContributionCents;
    }
    return InvestmentProjection(amountCents: balance, periods: maximumMonths);
  }

  static RequiredContributionResult firstMillionRequiredContribution({
    required int initialCents,
    required int monthlyRateBasisPoints,
    required int months,
    int targetCents = 100000000,
  }) {
    _nonNegative(initialCents, 'initialCents');
    _nonNegative(monthlyRateBasisPoints, 'monthlyRateBasisPoints');
    _positive(months, 'months');
    _positive(targetCents, 'targetCents');
    if (initialCents >= targetCents) {
      return RequiredContributionResult(
        monthlyContributionCents: 0,
        amountCents: initialCents,
        periods: months,
      );
    }
    var low = 0;
    var high = targetCents;
    while (low < high) {
      final int middle = (low + high) ~/ 2;
      final InvestmentProjection projection = _projectMonthly(
        initialCents: initialCents,
        monthlyContributionCents: middle,
        monthlyRateBasisPoints: monthlyRateBasisPoints,
        months: months,
      );
      if (projection.amountCents >= targetCents) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    final InvestmentProjection projection = _projectMonthly(
      initialCents: initialCents,
      monthlyContributionCents: low,
      monthlyRateBasisPoints: monthlyRateBasisPoints,
      months: months,
    );
    return RequiredContributionResult(
      monthlyContributionCents: low,
      amountCents: projection.amountCents,
      periods: months,
    );
  }

  static InvestmentProjection _projectMonthly({
    required int initialCents,
    required int monthlyContributionCents,
    required int monthlyRateBasisPoints,
    required int months,
  }) {
    var balance = initialCents;
    for (var month = 0; month < months; month++) {
      balance += _multiplyDivide(balance, monthlyRateBasisPoints, _rateScale);
      balance += monthlyContributionCents;
    }
    return InvestmentProjection(amountCents: balance, periods: months);
  }

  static InterestResult simpleInterest({
    required int principalCents,
    required int annualRateBasisPoints,
    required int days,
  }) {
    _nonNegative(principalCents, 'principalCents');
    _nonNegative(annualRateBasisPoints, 'annualRateBasisPoints');
    _positive(days, 'days');
    final interest = _multiplyDivide(
      principalCents * days,
      annualRateBasisPoints,
      _rateScale * 365,
    );
    return InterestResult(
      interestCents: interest,
      totalCents: principalCents + interest,
    );
  }

  static InterestResult compoundInterest({
    required int principalCents,
    required int monthlyRateBasisPoints,
    required int months,
    int monthlyContributionCents = 0,
  }) {
    _nonNegative(principalCents, 'principalCents');
    _nonNegative(monthlyRateBasisPoints, 'monthlyRateBasisPoints');
    _nonNegative(monthlyContributionCents, 'monthlyContributionCents');
    _positive(months, 'months');
    var amount = principalCents;
    for (var month = 0; month < months; month++) {
      amount += _multiplyDivide(amount, monthlyRateBasisPoints, _rateScale);
      amount += monthlyContributionCents;
    }
    return InterestResult(
      interestCents:
          amount - principalCents - monthlyContributionCents * months,
      totalCents: amount,
    );
  }

  static PercentageResult percentage({
    required int baseCents,
    required int rateBasisPoints,
    required PercentageOperation operation,
  }) {
    _nonNegative(baseCents, 'baseCents');
    _nonNegative(rateBasisPoints, 'rateBasisPoints');
    final delta = _multiplyDivide(baseCents, rateBasisPoints, _rateScale);
    final result = operation == PercentageOperation.increase
        ? baseCents + delta
        : baseCents >= delta
        ? baseCents - delta
        : 0;
    return PercentageResult(deltaCents: delta, resultCents: result);
  }

  static PercentageVariationResult percentageVariation({
    required int initialCents,
    required int finalCents,
  }) {
    _positive(initialCents, 'initialCents');
    _nonNegative(finalCents, 'finalCents');
    final int differenceCents = finalCents - initialCents;
    final int magnitudeBasisPoints = _multiplyDivide(
      differenceCents.abs(),
      _rateScale,
      initialCents,
    );
    return PercentageVariationResult(
      differenceCents: differenceCents,
      variationBasisPoints: differenceCents < 0
          ? -magnitudeBasisPoints
          : magnitudeBasisPoints,
    );
  }

  /// Graham: sqrt(22,5 × LPA × VPA), com LPA/VPA em centavos por ação.
  static int grahamFairPriceCents({
    required int earningsPerShareCents,
    required int bookValuePerShareCents,
  }) {
    _positive(earningsPerShareCents, 'earningsPerShareCents');
    _positive(bookValuePerShareCents, 'bookValuePerShareCents');
    return _integerSquareRoot(
      (earningsPerShareCents * bookValuePerShareCents * 45) ~/ 2,
    );
  }

  /// Bazin: dividendo anual por cota ÷ dividend yield desejado.
  static int bazinCeilingPriceCents({
    required int annualDividendPerShareCents,
    required int desiredYieldBasisPoints,
  }) {
    _positive(annualDividendPerShareCents, 'annualDividendPerShareCents');
    _positive(desiredYieldBasisPoints, 'desiredYieldBasisPoints');
    return _multiplyDivide(
      annualDividendPerShareCents,
      _rateScale,
      desiredYieldBasisPoints,
    );
  }

  static int _multiplyDivide(int value, int factor, int divisor) =>
      (value * factor + divisor ~/ 2) ~/ divisor;

  static int _integerSquareRoot(int value) {
    var low = 0;
    var high = value;
    var answer = 0;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final square = middle * middle;
      if (square <= value) {
        answer = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return answer;
  }

  static void _nonNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'Não pode ser negativo.');
    }
  }

  static void _positive(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'Deve ser maior que zero.');
    }
  }
}

enum PercentageOperation { increase, discount }

final class InvestmentProjection {
  const InvestmentProjection({
    required this.amountCents,
    required this.periods,
  });
  final int amountCents;
  final int periods;
}

final class RequiredContributionResult {
  const RequiredContributionResult({
    required this.monthlyContributionCents,
    required this.amountCents,
    required this.periods,
  });
  final int monthlyContributionCents;
  final int amountCents;
  final int periods;
}

final class InterestResult {
  const InterestResult({required this.interestCents, required this.totalCents});
  final int interestCents;
  final int totalCents;
}

final class PercentageResult {
  const PercentageResult({required this.deltaCents, required this.resultCents});
  final int deltaCents;
  final int resultCents;
}

final class PercentageVariationResult {
  const PercentageVariationResult({
    required this.differenceCents,
    required this.variationBasisPoints,
  });
  final int differenceCents;
  final int variationBasisPoints;
}

enum ManualAssetKind { stock, fii }

enum InvestmentFindingKind { positive, attention, insufficient }

final class InvestmentFinding {
  const InvestmentFinding(this.kind, this.message);
  final InvestmentFindingKind kind;
  final String message;
}

final class ManualAssetAnalysis {
  const ManualAssetAnalysis({
    required this.kind,
    required this.positive,
    required this.attention,
    required this.completedChecklistItems,
    required this.totalChecklistItems,
  });
  final ManualAssetKind kind;
  final bool positive;
  final bool attention;
  final int completedChecklistItems;
  final int totalChecklistItems;

  List<InvestmentFinding> get findings => <InvestmentFinding>[
    if (completedChecklistItems == 0)
      const InvestmentFinding(
        InvestmentFindingKind.insufficient,
        'Preencha seu checklist manual antes de comparar ativos.',
      )
    else if (completedChecklistItems < totalChecklistItems)
      const InvestmentFinding(
        InvestmentFindingKind.attention,
        'Checklist incompleto: confirme os critérios que ainda faltam.',
      )
    else
      const InvestmentFinding(
        InvestmentFindingKind.positive,
        'Checklist manual completo para a sua avaliação.',
      ),
    if (attention)
      const InvestmentFinding(
        InvestmentFindingKind.attention,
        'Há um ponto de atenção informado por você; revise os documentos do ativo.',
      ),
    if (positive)
      const InvestmentFinding(
        InvestmentFindingKind.positive,
        'Você marcou um ponto positivo manual. Isso não é recomendação de investimento.',
      ),
  ];
}

/// Compara somente critérios preenchidos pela pessoa, nunca cotação ou ordem.
final class ManualAssetComparison {
  const ManualAssetComparison({
    required this.firstName,
    required this.firstChecklistItems,
    required this.secondName,
    required this.secondChecklistItems,
  });

  final String firstName;
  final int firstChecklistItems;
  final String secondName;
  final int secondChecklistItems;

  InvestmentFinding get finding {
    if (firstName.trim().isEmpty || secondName.trim().isEmpty) {
      return const InvestmentFinding(
        InvestmentFindingKind.insufficient,
        'Informe os dois nomes para comparar critérios manuais.',
      );
    }
    if (firstChecklistItems == secondChecklistItems) {
      return const InvestmentFinding(
        InvestmentFindingKind.insufficient,
        'Os critérios preenchidos são equivalentes; inclua sua análise qualitativa.',
      );
    }
    final String name = firstChecklistItems > secondChecklistItems
        ? firstName.trim()
        : secondName.trim();
    return InvestmentFinding(
      InvestmentFindingKind.attention,
      '$name tem mais itens do seu checklist preenchidos; isso não é recomendação.',
    );
  }
}
