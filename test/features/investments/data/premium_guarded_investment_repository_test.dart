import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/data/premium_guarded_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_access_decision.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_policy.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

import '../../../support/fake_investment_repository.dart';
import '../../../support/fake_premium_entitlement_repository.dart';

void main() {
  test('acesso integral delega leitura e mutação manual', () async {
    final FakeInvestmentRepository delegate = FakeInvestmentRepository();
    final PremiumGuardedInvestmentRepository guarded =
        PremiumGuardedInvestmentRepository(
          delegate: delegate,
          accessReader: () => _access(syntheticPremiumEntitlement()),
        );

    await guarded.readWorkspace(
      ownerId: 'owner',
      serverOnly: true,
      includeIncome: true,
    );
    await guarded.createPortfolio(
      ownerId: 'owner',
      portfolioId: 'portfolio-1',
      draft: const InvestmentPortfolioDraft(
        name: 'Carteira sintética',
        description: '',
      ),
    );
    expect(delegate.readCalls, 1);
    expect(delegate.createPortfolioCalls, 1);
  });

  test('somente leitura consulta histórico e bloqueia mutação', () async {
    final FakeInvestmentRepository delegate = FakeInvestmentRepository();
    final PremiumGuardedInvestmentRepository guarded =
        PremiumGuardedInvestmentRepository(
          delegate: delegate,
          accessReader: () => _access(
            syntheticPremiumEntitlement(
              status: PremiumEntitlementStatus.expired,
            ),
          ),
        );

    await guarded.readWorkspace(ownerId: 'owner', serverOnly: true);
    expect(
      () => guarded.createPortfolio(
        ownerId: 'owner',
        portfolioId: 'portfolio-blocked',
        draft: const InvestmentPortfolioDraft(
          name: 'Não criada',
          description: '',
        ),
      ),
      throwsA(
        isA<InvestmentFailure>().having(
          (InvestmentFailure value) => value.kind,
          'kind',
          InvestmentFailureKind.premiumRequired,
        ),
      ),
    );
    expect(delegate.createPortfolioCalls, 0);
  });

  test('manual não autoriza proventos e income não autoriza manual', () async {
    final FakeInvestmentRepository manualDelegate = FakeInvestmentRepository();
    final PremiumGuardedInvestmentRepository manualGuard =
        PremiumGuardedInvestmentRepository(
          delegate: manualDelegate,
          accessReader: () => _access(
            syntheticPremiumEntitlement(
              capabilities: const <PremiumCapability>{
                PremiumCapability.investmentsManual,
              },
            ),
          ),
        );
    expect(
      () => manualGuard.createIncomeEvent(
        ownerId: 'owner',
        eventId: 'income-1',
        draft: _incomeDraft(),
      ),
      throwsA(isA<InvestmentFailure>()),
    );

    final FakeInvestmentRepository incomeDelegate = FakeInvestmentRepository();
    final PremiumGuardedInvestmentRepository incomeGuard =
        PremiumGuardedInvestmentRepository(
          delegate: incomeDelegate,
          accessReader: () => _access(
            syntheticPremiumEntitlement(
              capabilities: const <PremiumCapability>{
                PremiumCapability.investmentIncome,
              },
            ),
          ),
        );
    expect(
      () => incomeGuard.createPortfolio(
        ownerId: 'owner',
        portfolioId: 'portfolio-1',
        draft: const InvestmentPortfolioDraft(
          name: 'Não criada',
          description: '',
        ),
      ),
      throwsA(isA<InvestmentFailure>()),
    );
  });

  test('confirmação indisponível falha fechada e não chama delegate', () async {
    final FakeInvestmentRepository delegate = FakeInvestmentRepository();
    final PremiumGuardedInvestmentRepository guarded =
        PremiumGuardedInvestmentRepository(
          delegate: delegate,
          accessReader: () => InvestmentPremiumAccessState.confirmationError(
            problem: InvestmentPremiumAccessProblem.confirmationUnavailable,
            safeMessage: 'Indisponível.',
          ),
        );

    expect(
      () => guarded.readWorkspace(ownerId: 'owner', serverOnly: true),
      throwsA(
        isA<InvestmentFailure>().having(
          (InvestmentFailure value) => value.kind,
          'kind',
          InvestmentFailureKind.premiumConfirmationUnavailable,
        ),
      ),
    );
    expect(delegate.readCalls, 0);
  });
}

InvestmentPremiumAccessState _access(PremiumEntitlement entitlement) {
  const PremiumEntitlementPolicy policy = PremiumEntitlementPolicy(
    environment: PremiumEnvironment.development,
  );
  PremiumAccessDecision decide(
    PremiumCapability capability,
    PremiumAccessIntent intent,
  ) => policy.decide(
    entitlement: entitlement,
    capability: capability,
    intent: intent,
    referenceInstant: DateTime.utc(2026, 8, 10, 12),
  );
  final PremiumAccessDecision manualRead = decide(
    PremiumCapability.investmentsManual,
    PremiumAccessIntent.read,
  );
  final PremiumAccessDecision manualMutation = decide(
    PremiumCapability.investmentsManual,
    PremiumAccessIntent.mutate,
  );
  final PremiumAccessDecision incomeRead = decide(
    PremiumCapability.investmentIncome,
    PremiumAccessIntent.read,
  );
  final PremiumAccessDecision incomeMutation = decide(
    PremiumCapability.investmentIncome,
    PremiumAccessIntent.mutate,
  );
  return InvestmentPremiumAccessState(
    status: manualMutation.mode == PremiumAccessMode.full
        ? InvestmentPremiumAccessStatus.full
        : manualRead.isAllowed
        ? InvestmentPremiumAccessStatus.readOnly
        : InvestmentPremiumAccessStatus.denied,
    problem: InvestmentPremiumAccessProblem.none,
    manualRead: manualRead,
    manualMutation: manualMutation,
    incomeRead: incomeRead,
    incomeMutation: incomeMutation,
    isServerConfirmed: true,
    safeMessage: 'Estado sintético.',
  );
}

InvestmentIncomeDraft _incomeDraft() => InvestmentIncomeDraft(
  portfolioId: 'portfolio-1',
  assetId: 'portfolio-1__PETR4',
  type: InvestmentIncomeType.dividend,
  inputMode: InvestmentIncomeInputMode.total,
  exDate: null,
  expectedPaymentDate: DateTime.utc(2026, 8, 20, 3),
  eligibleQuantityScaled: null,
  unitAmountScaled: null,
  grossAmountCents: 1000,
  withholdingTaxCents: 0,
  notes: '',
);
