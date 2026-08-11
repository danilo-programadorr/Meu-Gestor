import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/google_play_billing_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/google_play_subscription_management.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_purchase_identity_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_purchase_verification_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_identity_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_purchase_verification_gateway.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_subscription_management.dart';

final Provider<PremiumProductCatalogConfiguration>
premiumProductCatalogConfigurationProvider =
    Provider<PremiumProductCatalogConfiguration>(
      (Ref ref) => const PremiumProductCatalogConfiguration(
        monthlyProductId: String.fromEnvironment(
          'GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID',
        ),
        annualProductId: String.fromEnvironment(
          'GOOGLE_PLAY_PREMIUM_ANNUAL_PRODUCT_ID',
        ),
        androidPackageName: String.fromEnvironment(
          'GOOGLE_PLAY_ANDROID_PACKAGE_NAME',
        ),
      ),
    );

final Provider<PremiumBillingGateway> premiumBillingGatewayProvider =
    Provider<PremiumBillingGateway>((Ref ref) {
      final GooglePlayBillingGateway gateway = GooglePlayBillingGateway();
      ref.onDispose(gateway.dispose);
      return gateway;
    });

final Provider<PremiumPurchaseVerificationGateway>
premiumPurchaseVerificationGatewayProvider =
    Provider<PremiumPurchaseVerificationGateway>(
      (Ref ref) => const DisabledPremiumPurchaseVerificationGateway(),
    );

final Provider<PremiumPurchaseIdentityGateway>
premiumPurchaseIdentityGatewayProvider =
    Provider<PremiumPurchaseIdentityGateway>(
      (Ref ref) => const DisabledPremiumPurchaseIdentityGateway(),
    );

final Provider<bool> premiumBillingAppCheckPreparedProvider = Provider<bool>(
  (Ref ref) => false,
);

final Provider<PremiumSubscriptionManagement>
premiumSubscriptionManagementProvider = Provider<PremiumSubscriptionManagement>(
  (Ref ref) => GooglePlaySubscriptionManagement(
    configuration: ref.watch(premiumProductCatalogConfigurationProvider),
  ),
);

final Provider<PremiumBillingAvailability> premiumBillingAvailabilityProvider =
    Provider<PremiumBillingAvailability>((Ref ref) {
      ref.watch(authStateProvider);
      ref.watch(profileGateControllerProvider);
      final PremiumProductCatalogConfiguration configuration = ref.watch(
        premiumProductCatalogConfigurationProvider,
      );
      final PremiumPurchaseVerificationGateway verifier = ref.watch(
        premiumPurchaseVerificationGatewayProvider,
      );
      final PremiumPurchaseIdentityGateway identity = ref.watch(
        premiumPurchaseIdentityGatewayProvider,
      );
      return PremiumBillingAvailability(
        storeAvailable: configuration.hasConfiguredProducts,
        productsConfigured: configuration.hasConfiguredProducts,
        backendVerificationAvailable: verifier.isAvailable,
        identityAvailable: identity.isAvailable,
        appCheckPrepared: ref.watch(premiumBillingAppCheckPreparedProvider),
        environmentValid:
            ref.watch(appEnvironmentProvider) == AppEnvironment.development,
        eligibleUser: verifiedFinancialOwner(ref) != null,
      );
    });
