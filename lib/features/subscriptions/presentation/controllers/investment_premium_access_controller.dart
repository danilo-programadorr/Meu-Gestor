import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_access_decision.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_policy.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';

enum InvestmentPremiumAccessStatus { full, readOnly, denied, confirmationError }

enum InvestmentPremiumAccessProblem {
  none,
  missing,
  pending,
  invalidDocument,
  incompatibleEnvironment,
  capabilityMissing,
  confirmationUnavailable,
  unauthenticated,
}

final class InvestmentPremiumAccessState {
  const InvestmentPremiumAccessState({
    required this.status,
    required this.problem,
    required this.manualRead,
    required this.manualMutation,
    required this.incomeRead,
    required this.incomeMutation,
    required this.isServerConfirmed,
    required this.safeMessage,
    this.additionalRead = const <PremiumCapability, PremiumAccessDecision>{},
  });

  factory InvestmentPremiumAccessState.denied({
    required InvestmentPremiumAccessProblem problem,
    required String safeMessage,
    PremiumAccessDecision? manualRead,
    PremiumAccessDecision? manualMutation,
    PremiumAccessDecision? incomeRead,
    PremiumAccessDecision? incomeMutation,
    bool isServerConfirmed = true,
  }) => InvestmentPremiumAccessState(
    status: InvestmentPremiumAccessStatus.denied,
    problem: problem,
    manualRead: manualRead,
    manualMutation: manualMutation,
    incomeRead: incomeRead,
    incomeMutation: incomeMutation,
    isServerConfirmed: isServerConfirmed,
    safeMessage: safeMessage,
  );

  factory InvestmentPremiumAccessState.confirmationError({
    required InvestmentPremiumAccessProblem problem,
    required String safeMessage,
  }) => InvestmentPremiumAccessState(
    status: InvestmentPremiumAccessStatus.confirmationError,
    problem: problem,
    manualRead: null,
    manualMutation: null,
    incomeRead: null,
    incomeMutation: null,
    isServerConfirmed: false,
    safeMessage: safeMessage,
  );

  final InvestmentPremiumAccessStatus status;
  final InvestmentPremiumAccessProblem problem;
  final PremiumAccessDecision? manualRead;
  final PremiumAccessDecision? manualMutation;
  final PremiumAccessDecision? incomeRead;
  final PremiumAccessDecision? incomeMutation;
  final bool isServerConfirmed;
  final String safeMessage;
  final Map<PremiumCapability, PremiumAccessDecision> additionalRead;

  bool get canReadManual => isServerConfirmed && manualRead?.isAllowed == true;
  bool get canMutateManual =>
      isServerConfirmed && manualMutation?.mode == PremiumAccessMode.full;
  bool get canReadIncome => isServerConfirmed && incomeRead?.isAllowed == true;
  bool get canMutateIncome =>
      isServerConfirmed && incomeMutation?.mode == PremiumAccessMode.full;
  bool get isReadOnly => status == InvestmentPremiumAccessStatus.readOnly;

  bool canRead(PremiumCapability capability) => switch (capability) {
    PremiumCapability.investmentsManual => canReadManual,
    PremiumCapability.investmentIncome => canReadIncome,
    _ => isServerConfirmed && additionalRead[capability]?.isAllowed == true,
  };

  bool canMutate(PremiumCapability capability) => switch (capability) {
    PremiumCapability.investmentsManual => canMutateManual,
    PremiumCapability.investmentIncome => canMutateIncome,
    _ => false,
  };
}

final Provider<DateTime Function()> premiumAccessReferenceClockProvider =
    Provider<DateTime Function()>(
      (Ref ref) =>
          () => DateTime.now().toUtc(),
    );

final AsyncNotifierProvider<
  InvestmentPremiumAccessController,
  InvestmentPremiumAccessState
>
investmentPremiumAccessControllerProvider =
    AsyncNotifierProvider.autoDispose<
      InvestmentPremiumAccessController,
      InvestmentPremiumAccessState
    >(InvestmentPremiumAccessController.new);

final class InvestmentPremiumAccessController
    extends AsyncNotifier<InvestmentPremiumAccessState> {
  int _requestVersion = 0;

  @override
  Future<InvestmentPremiumAccessState> build() {
    ref.watch(authStateProvider);
    ref.watch(profileGateControllerProvider);
    ref.onDispose(() => _requestVersion += 1);
    return _load();
  }

  Future<void> retry() async {
    state = const AsyncLoading<InvestmentPremiumAccessState>();
    state = AsyncData<InvestmentPremiumAccessState>(await _load());
  }

  Future<InvestmentPremiumAccessState> _load() async {
    final int requestVersion = ++_requestVersion;
    final String? ownerId = verifiedFinancialOwner(ref);
    if (ownerId == null) {
      return InvestmentPremiumAccessState.denied(
        problem: InvestmentPremiumAccessProblem.unauthenticated,
        safeMessage:
            'Confirme sua sessão e seu perfil antes de acessar o Premium.',
        isServerConfirmed: false,
      );
    }

    try {
      final PremiumEntitlementReadResult result = await ref
          .read(premiumEntitlementRepositoryProvider)
          .refreshFromServer(ownerId: ownerId);
      if (requestVersion != _requestVersion ||
          verifiedFinancialOwner(ref) != ownerId) {
        return InvestmentPremiumAccessState.confirmationError(
          problem: InvestmentPremiumAccessProblem.confirmationUnavailable,
          safeMessage: 'Sua sessão mudou. Confirme novamente o acesso Premium.',
        );
      }
      if (!result.isFromServer || result.hasPendingWrites) {
        return InvestmentPremiumAccessState.confirmationError(
          problem: InvestmentPremiumAccessProblem.confirmationUnavailable,
          safeMessage: 'Não foi possível confirmar o Premium com o servidor.',
        );
      }
      if (result.presence == PremiumEntitlementPresence.absent) {
        return InvestmentPremiumAccessState.denied(
          problem: InvestmentPremiumAccessProblem.missing,
          safeMessage:
              'Investimentos é um recurso Premium. A assinatura será disponibilizada futuramente.',
        );
      }
      return _decide(ownerId: ownerId, entitlement: result.entitlement!);
    } on PremiumEntitlementFailure catch (failure) {
      final bool invalid =
          failure.kind == PremiumEntitlementFailureKind.incompatibleSchema ||
          failure.kind == PremiumEntitlementFailureKind.invalidState ||
          failure.kind == PremiumEntitlementFailureKind.invalidPeriod ||
          failure.kind == PremiumEntitlementFailureKind.inconsistentData;
      if (invalid) {
        return InvestmentPremiumAccessState.denied(
          problem: InvestmentPremiumAccessProblem.invalidDocument,
          safeMessage:
              'O acesso Premium não pôde ser validado. Seus dados permanecem protegidos.',
        );
      }
      return InvestmentPremiumAccessState.confirmationError(
        problem: InvestmentPremiumAccessProblem.confirmationUnavailable,
        safeMessage: failure.safeMessage,
      );
    } on Object {
      return InvestmentPremiumAccessState.confirmationError(
        problem: InvestmentPremiumAccessProblem.confirmationUnavailable,
        safeMessage:
            'Não foi possível confirmar o Premium. Verifique sua conexão e tente novamente.',
      );
    }
  }

  InvestmentPremiumAccessState _decide({
    required String ownerId,
    required PremiumEntitlement entitlement,
  }) {
    if (entitlement.ownerId != ownerId) {
      return InvestmentPremiumAccessState.denied(
        problem: InvestmentPremiumAccessProblem.invalidDocument,
        safeMessage:
            'O acesso Premium não pôde ser validado. Seus dados permanecem protegidos.',
      );
    }
    final PremiumEnvironment environment = switch (ref.read(
      appEnvironmentProvider,
    )) {
      AppEnvironment.development => PremiumEnvironment.development,
      AppEnvironment.production => PremiumEnvironment.production,
    };
    final PremiumEntitlementPolicy policy = PremiumEntitlementPolicy(
      environment: environment,
    );
    final DateTime referenceInstant = ref
        .read(premiumAccessReferenceClockProvider)()
        .toUtc();
    PremiumAccessDecision decision(
      PremiumCapability capability,
      PremiumAccessIntent intent,
    ) => policy.decide(
      entitlement: entitlement,
      capability: capability,
      intent: intent,
      referenceInstant: referenceInstant,
    );

    final PremiumAccessDecision manualRead = decision(
      PremiumCapability.investmentsManual,
      PremiumAccessIntent.read,
    );
    final PremiumAccessDecision manualMutation = decision(
      PremiumCapability.investmentsManual,
      PremiumAccessIntent.mutate,
    );
    final PremiumAccessDecision incomeRead = decision(
      PremiumCapability.investmentIncome,
      PremiumAccessIntent.read,
    );
    final PremiumAccessDecision incomeMutation = decision(
      PremiumCapability.investmentIncome,
      PremiumAccessIntent.mutate,
    );
    final PremiumAccessDecision calculatorsRead = decision(
      PremiumCapability.investmentCalculators,
      PremiumAccessIntent.read,
    );
    final PremiumAccessDecision analysisRead = decision(
      PremiumCapability.investmentAnalysis,
      PremiumAccessIntent.read,
    );
    final PremiumAccessDecision quotesRead = decision(
      PremiumCapability.investmentQuotes,
      PremiumAccessIntent.read,
    );
    final Map<PremiumCapability, PremiumAccessDecision> additionalRead =
        <PremiumCapability, PremiumAccessDecision>{
          PremiumCapability.investmentCalculators: calculatorsRead,
          PremiumCapability.investmentAnalysis: analysisRead,
          PremiumCapability.investmentQuotes: quotesRead,
        };

    if (!manualRead.isAllowed) {
      return InvestmentPremiumAccessState.denied(
        problem: _problemFor(manualRead.reason),
        safeMessage: _deniedMessage(manualRead.reason),
        manualRead: manualRead,
        manualMutation: manualMutation,
        incomeRead: incomeRead,
        incomeMutation: incomeMutation,
      );
    }
    final bool full = manualMutation.mode == PremiumAccessMode.full;
    return InvestmentPremiumAccessState(
      status: full
          ? InvestmentPremiumAccessStatus.full
          : InvestmentPremiumAccessStatus.readOnly,
      problem: InvestmentPremiumAccessProblem.none,
      manualRead: manualRead,
      manualMutation: manualMutation,
      incomeRead: incomeRead,
      incomeMutation: incomeMutation,
      additionalRead: additionalRead,
      isServerConfirmed: true,
      safeMessage: full
          ? 'Acesso Premium confirmado.'
          : 'Seu acesso Premium terminou. Seus dados continuam preservados e disponíveis somente para consulta.',
    );
  }

  static InvestmentPremiumAccessProblem _problemFor(
    PremiumAccessReason reason,
  ) => switch (reason) {
    PremiumAccessReason.pendingServerConfirmation =>
      InvestmentPremiumAccessProblem.pending,
    PremiumAccessReason.environmentMismatch =>
      InvestmentPremiumAccessProblem.incompatibleEnvironment,
    PremiumAccessReason.capabilityNotGranted =>
      InvestmentPremiumAccessProblem.capabilityMissing,
    PremiumAccessReason.missingEntitlement =>
      InvestmentPremiumAccessProblem.missing,
    _ => InvestmentPremiumAccessProblem.invalidDocument,
  };

  static String _deniedMessage(PremiumAccessReason reason) => switch (reason) {
    PremiumAccessReason.pendingServerConfirmation =>
      'Seu Premium ainda aguarda confirmação do servidor.',
    PremiumAccessReason.environmentMismatch =>
      'O Premium não pertence a este ambiente do aplicativo.',
    PremiumAccessReason.capabilityNotGranted =>
      'Este acesso Premium não inclui o acompanhamento manual de investimentos.',
    _ =>
      'Investimentos é um recurso Premium. A assinatura será disponibilizada futuramente.',
  };
}
