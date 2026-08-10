enum PremiumCapability {
  investmentsManual,
  investmentIncome,
  investmentQuotes,
  investmentCalculators,
  investmentAnalysis,
}

enum PremiumAccessIntent { read, mutate, consumeService }

extension PremiumCapabilityProperties on PremiumCapability {
  bool get preservesUserData =>
      this == PremiumCapability.investmentsManual ||
      this == PremiumCapability.investmentIncome;

  bool get dependsOnRecurringService =>
      this == PremiumCapability.investmentQuotes;
}
