import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';

import '../support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'inicializa em pt-BR e direciona usuário não autenticado ao login',
    (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository();
      addTearDown(repository.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(
              AppEnvironment.development,
            ),
            firebaseStartupProvider.overrideWithValue(
              const FirebaseStartupAvailable(),
            ),
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MeuGestorFinanceiroApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(
        find.text('Entre para gerenciar suas finanças com segurança.'),
        findsOneWidget,
      );

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.locale, const Locale('pt', 'BR'));
      expect(app.themeMode, ThemeMode.system);
    },
  );

  testWidgets('troca claro e escuro sem perder a rota atual', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
        firebaseStartupProvider.overrideWithValue(
          const FirebaseStartupAvailable(),
        ),
        authRepositoryProvider.overrideWithValue(repository),
        initialAppThemePreferenceProvider.overrideWithValue(
          AppThemePreference.dark,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MeuGestorFinanceiroApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await container
        .read(appThemePreferenceControllerProvider.notifier)
        .select(AppThemePreference.light);
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
