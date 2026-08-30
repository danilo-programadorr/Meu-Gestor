enum FairValueAssetKind { stock, bdr, fii }

enum FairValueStatus {
  available,
  unavailable,
  stale,
  incompatible,
  bdrPendingNormalization,
}

final class FairValueSnapshot {
  const FairValueSnapshot({
    required this.kind,
    required this.currencyCode,
    required this.sourceAt,
    required this.quoteCents,
    this.earningsPerShareCents,
    this.bookValuePerShareCents,
    this.netAssetValuePerShareCents,
    this.isStale = false,
  });

  final FairValueAssetKind kind;
  final String currencyCode;
  final DateTime sourceAt;
  final int? quoteCents;
  final int? earningsPerShareCents;
  final int? bookValuePerShareCents;
  final int? netAssetValuePerShareCents;
  final bool isStale;
}

abstract interface class FairValueAutomaticDataSource {
  /// Fonte futura deve fornecer cotação e fundamentos validados, sem input manual.
  Future<FairValueSnapshot?> readValidated(String assetId);
}

final class FairValueResult {
  const FairValueResult({
    required this.status,
    this.fairPriceCents,
    this.theoreticalPotentialBasisPoints,
    this.priceToBookBasisPoints,
    this.premiumDiscountBasisPoints,
  });

  final FairValueStatus status;
  final int? fairPriceCents;
  final int? theoreticalPotentialBasisPoints;
  final int? priceToBookBasisPoints;
  final int? premiumDiscountBasisPoints;
}

abstract final class FairValueCalculator {
  static FairValueResult calculate(FairValueSnapshot? snapshot) {
    if (snapshot == null) {
      return const FairValueResult(status: FairValueStatus.unavailable);
    }
    if (snapshot.currencyCode != 'BRL') {
      return const FairValueResult(status: FairValueStatus.incompatible);
    }
    if (snapshot.isStale) {
      return const FairValueResult(status: FairValueStatus.stale);
    }
    if (snapshot.kind == FairValueAssetKind.bdr) {
      return const FairValueResult(
        status: FairValueStatus.bdrPendingNormalization,
      );
    }
    final int? quote = snapshot.quoteCents;
    if (quote == null || quote <= 0) {
      return const FairValueResult(status: FairValueStatus.unavailable);
    }
    if (snapshot.kind == FairValueAssetKind.fii) {
      final int? nav = snapshot.netAssetValuePerShareCents;
      if (nav == null || nav <= 0) {
        return const FairValueResult(status: FairValueStatus.unavailable);
      }
      return FairValueResult(
        status: FairValueStatus.available,
        priceToBookBasisPoints: quote * 10000 ~/ nav,
        premiumDiscountBasisPoints: (quote * 10000 ~/ nav) - 10000,
      );
    }
    final int? eps = snapshot.earningsPerShareCents;
    final int? book = snapshot.bookValuePerShareCents;
    if (eps == null || book == null || eps <= 0 || book <= 0) {
      return const FairValueResult(status: FairValueStatus.unavailable);
    }
    // sqrt(22.5 × LPA × VPA), sem ponto flutuante para valores monetários.
    final int fairCents = _roundedIntegerSquareRoot(225 * eps * book ~/ 10);
    return FairValueResult(
      status: FairValueStatus.available,
      fairPriceCents: fairCents,
      theoreticalPotentialBasisPoints: (fairCents * 10000 ~/ quote) - 10000,
    );
  }

  static int _roundedIntegerSquareRoot(int value) {
    if (value <= 0) return 0;
    int estimate = value;
    int next = (estimate + value ~/ estimate) ~/ 2;
    while (next < estimate) {
      estimate = next;
      next = (estimate + value ~/ estimate) ~/ 2;
    }
    final int upper = estimate + 1;
    return value - estimate * estimate > upper * upper - value
        ? upper
        : estimate;
  }
}
