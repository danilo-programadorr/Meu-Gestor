import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/investments/data/premium_guarded_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

final Provider<DateTime Function()> investmentClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

final Provider<InvestmentDiagnostics> investmentDiagnosticsProvider =
    Provider<InvestmentDiagnostics>(
      (Ref ref) =>
          InvestmentDiagnostics(environment: ref.watch(appEnvironmentProvider)),
    );

final Provider<InvestmentRepository> rawInvestmentRepositoryProvider =
    Provider<InvestmentRepository>(
      (Ref ref) => FirebaseInvestmentRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        diagnostics: ref.watch(investmentDiagnosticsProvider),
        now: ref.watch(investmentClockProvider),
      ),
    );

final Provider<InvestmentRepository> investmentRepositoryProvider =
    Provider<InvestmentRepository>(
      (Ref ref) => PremiumGuardedInvestmentRepository(
        delegate: ref.watch(rawInvestmentRepositoryProvider),
        accessReader: () =>
            ref.read(investmentPremiumAccessControllerProvider).value,
      ),
    );
