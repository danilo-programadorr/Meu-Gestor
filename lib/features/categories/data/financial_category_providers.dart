import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/categories/data/firebase_financial_category_repository.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';

final Provider<FinancialCategoryDiagnostics>
financialCategoryDiagnosticsProvider = Provider<FinancialCategoryDiagnostics>(
  (Ref ref) => FinancialCategoryDiagnostics(
    environment: ref.watch(appEnvironmentProvider),
  ),
);

final Provider<FinancialCategoryRepository>
financialCategoryRepositoryProvider = Provider<FinancialCategoryRepository>(
  (Ref ref) => FirebaseFinancialCategoryRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    diagnostics: ref.watch(financialCategoryDiagnosticsProvider),
  ),
);
