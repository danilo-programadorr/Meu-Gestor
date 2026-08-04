import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';

Future<void> bootstrap({
  FirebaseInitializer? firebaseInitializer,
  AppThemePreferenceStore? themePreferenceStore,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';

  final AppEnvironment environment = AppEnvironment.fromDefine(
    const String.fromEnvironment(
      'APP_ENV',
      defaultValue: AppEnvironment.developmentValue,
    ),
  );
  final FirebaseStartupState firebaseStartupState =
      await initializeFirebaseForEnvironment(
        environment: environment,
        initializer: firebaseInitializer ?? const DefaultFirebaseInitializer(),
      );
  AppThemePreferenceStore appearanceStore =
      themePreferenceStore ?? VolatileAppThemePreferenceStore();
  AppThemePreference initialThemePreference = AppThemePreference.system;
  try {
    if (themePreferenceStore == null) {
      appearanceStore = await SharedPreferencesAppThemePreferenceStore.create();
    }
    initialThemePreference = await appearanceStore.load();
  } on Object {
    // Aparência é uma preferência não crítica. Falhas locais não bloqueiam o app.
  }

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        firebaseStartupProvider.overrideWithValue(firebaseStartupState),
        appThemePreferenceStoreProvider.overrideWithValue(appearanceStore),
        initialAppThemePreferenceProvider.overrideWithValue(
          initialThemePreference,
        ),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
}
