import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/closed_test_activation_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_billing_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/pages/premium_page.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_closed_test_activation_repository.dart';
import '../../../support/fake_premium_billing.dart';
import '../../../support/fake_premium_entitlement_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets(
    'página Premium mostra preparação sem preço fictício em tela estreita',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final FakeAuthRepository auth = FakeAuthRepository(
        initialUser: const AuthUser(
          id: 'owner',
          displayName: 'Pessoa Teste',
          emailVerified: true,
        ),
      );
      addTearDown(auth.close);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
          authRepositoryProvider.overrideWithValue(auth),
          userProfileRepositoryProvider.overrideWithValue(
            FakeUserProfileRepository(
              initialProfile: createTestProfile(ownerId: 'owner'),
            ),
          ),
          premiumEntitlementRepositoryProvider.overrideWithValue(
            FakePremiumEntitlementRepository(),
          ),
          closedTestActivationRepositoryProvider.overrideWithValue(
            FakeClosedTestActivationRepository()
              ..failure = const ClosedTestActivationFailure(
                kind: ClosedTestActivationFailureKind.notAuthorized,
                safeMessage: 'O acesso ao teste fechado não está disponível.',
                code: 'synthetic_not_authorized',
              ),
          ),
          premiumBillingGatewayProvider.overrideWithValue(
            FakePremiumBillingGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final Completer<void> profileReady = Completer<void>();
      final ProviderSubscription<AsyncValue<ProfileGateState>> profile =
          container.listen(profileGateControllerProvider, (_, next) {
            if (next.value?.isTerminal == true && !profileReady.isCompleted) {
              profileReady.complete();
            }
          }, fireImmediately: true);
      addTearDown(profile.close);
      await profileReady.future;

      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const PremiumPage(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Assinaturas em preparação'), findsWidgets);
      expect(find.text(r'R$ 9,90'), findsNothing);
      expect(
        find.text('Acompanhamento manual de investimentos'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Restaurar assinatura'), 180);
      expect(find.text('Restaurar assinatura'), findsOneWidget);
      expect(find.text('Gerenciar assinatura na Google Play'), findsOneWidget);
    },
  );
}
