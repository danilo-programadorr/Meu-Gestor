import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';

Future<void> bootstrap({FirebaseInitializer? firebaseInitializer}) async {
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

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        firebaseStartupProvider.overrideWithValue(firebaseStartupState),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
}
