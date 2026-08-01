import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/firebase_financial_account_repository.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';

final Provider<FinancialAccountDiagnostics>
financialAccountDiagnosticsProvider = Provider<FinancialAccountDiagnostics>(
  (Ref ref) => FinancialAccountDiagnostics(
    environment: ref.watch(appEnvironmentProvider),
  ),
);

final Provider<FinancialAccountRepository> financialAccountRepositoryProvider =
    Provider<FinancialAccountRepository>(
      (Ref ref) => FirebaseFinancialAccountRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        diagnostics: ref.watch(financialAccountDiagnosticsProvider),
      ),
    );
