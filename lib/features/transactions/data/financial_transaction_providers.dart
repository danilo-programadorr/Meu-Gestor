import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/firebase_financial_transaction_repository.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_repository.dart';

final Provider<DateTime Function()> financialClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

final Provider<FinancialTransactionDiagnostics>
financialTransactionDiagnosticsProvider =
    Provider<FinancialTransactionDiagnostics>(
      (Ref ref) => FinancialTransactionDiagnostics(
        environment: ref.watch(appEnvironmentProvider),
      ),
    );

final Provider<FinancialTransactionRepository>
financialTransactionRepositoryProvider =
    Provider<FinancialTransactionRepository>(
      (Ref ref) => FirebaseFinancialTransactionRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        diagnostics: ref.watch(financialTransactionDiagnosticsProvider),
        now: ref.watch(financialClockProvider),
      ),
    );
