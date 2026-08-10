import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';

enum PremiumPlan { free, monthly, annual }

extension PremiumPlanProperties on PremiumPlan {
  bool get isPremium => this != PremiumPlan.free;

  Set<PremiumCapability> get includedCapabilities => switch (this) {
    PremiumPlan.free => const <PremiumCapability>{},
    PremiumPlan.monthly || PremiumPlan.annual => const <PremiumCapability>{
      PremiumCapability.investmentsManual,
      PremiumCapability.investmentIncome,
      PremiumCapability.investmentQuotes,
      PremiumCapability.investmentCalculators,
      PremiumCapability.investmentAnalysis,
    },
  };
}
