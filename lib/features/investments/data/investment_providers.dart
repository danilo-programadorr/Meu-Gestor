import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_asset_directory.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_quote_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_asset_directory.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';

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
      (Ref ref) => ref.watch(rawInvestmentRepositoryProvider),
    );

final Provider<InvestmentQuoteRepository> investmentQuoteRepositoryProvider =
    Provider<InvestmentQuoteRepository>(
      (Ref ref) => FirebaseInvestmentQuoteRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
      ),
    );

final Provider<InvestmentAssetDirectory> investmentAssetDirectoryProvider =
    Provider<InvestmentAssetDirectory>((Ref ref) {
      if (ref.watch(appEnvironmentProvider) != AppEnvironment.development) {
        return const _DisabledInvestmentAssetDirectory();
      }
      return FirebaseInvestmentAssetDirectory(
        functions: FirebaseFunctions.instanceFor(
          region: FirebaseInvestmentAssetDirectory.callableRegion,
        ),
      );
    });

final class _DisabledInvestmentAssetDirectory
    implements InvestmentAssetDirectory {
  const _DisabledInvestmentAssetDirectory();

  @override
  Future<List<InvestmentAssetDirectoryEntry>> search(String query) async =>
      const <InvestmentAssetDirectoryEntry>[];
}
