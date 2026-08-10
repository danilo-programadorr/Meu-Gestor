import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firebase_premium_entitlement_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_repository.dart';

final Provider<PremiumEntitlementDiagnostics>
premiumEntitlementDiagnosticsProvider = Provider<PremiumEntitlementDiagnostics>(
  (Ref ref) => PremiumEntitlementDiagnostics(
    environment: ref.watch(appEnvironmentProvider),
  ),
);

final Provider<PremiumEntitlementRepository>
premiumEntitlementRepositoryProvider = Provider<PremiumEntitlementRepository>(
  (Ref ref) => FirebasePremiumEntitlementRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    diagnostics: ref.watch(premiumEntitlementDiagnosticsProvider),
  ),
);

final Provider<String?> premiumEntitlementOwnerProvider = Provider<String?>((
  Ref ref,
) {
  final value = ref.watch(authStateProvider).value;
  return value?.emailVerified == true ? value!.id : null;
});

final premiumEntitlementReadProvider =
    FutureProvider.family<PremiumEntitlementReadResult, String>((
      Ref ref,
      String ownerId,
    ) {
      return ref
          .watch(premiumEntitlementRepositoryProvider)
          .refreshFromServer(ownerId: ownerId);
    });

final premiumEntitlementWatchProvider =
    StreamProvider.family<PremiumEntitlementReadResult, String>((
      Ref ref,
      String ownerId,
    ) {
      return ref
          .watch(premiumEntitlementRepositoryProvider)
          .watchConfirmed(ownerId: ownerId);
    });
