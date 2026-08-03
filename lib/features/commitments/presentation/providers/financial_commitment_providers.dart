import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/financial_commitment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/commitments/data/firebase_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

final Provider<FinancialCommitmentDiagnostics>
financialCommitmentDiagnosticsProvider =
    Provider<FinancialCommitmentDiagnostics>(
      (Ref ref) => FinancialCommitmentDiagnostics(
        environment: ref.watch(appEnvironmentProvider),
      ),
    );

final Provider<FinancialCommitmentRepository>
financialCommitmentRepositoryProvider = Provider<FinancialCommitmentRepository>(
  (Ref ref) => FirebaseCommitmentRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    diagnostics: ref.watch(financialCommitmentDiagnosticsProvider),
    now: ref.watch(financialClockProvider),
  ),
);
