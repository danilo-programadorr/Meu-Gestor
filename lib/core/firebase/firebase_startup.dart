import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

sealed class FirebaseStartupState {
  const FirebaseStartupState();

  bool get isAvailable => this is FirebaseStartupAvailable;
}

final class FirebaseStartupInitializing extends FirebaseStartupState {
  const FirebaseStartupInitializing();
}

final class FirebaseStartupAvailable extends FirebaseStartupState {
  const FirebaseStartupAvailable();
}

final class FirebaseStartupFailure extends FirebaseStartupState {
  const FirebaseStartupFailure();
}

final class FirebaseStartupProductionBlocked extends FirebaseStartupState {
  const FirebaseStartupProductionBlocked();
}

abstract interface class FirebaseInitializer {
  Future<void> initialize();
}

abstract interface class AppCheckInitializer {
  Future<void> activate(AppEnvironment environment);
}

final class DefaultFirebaseInitializer implements FirebaseInitializer {
  const DefaultFirebaseInitializer();

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
  }
}

final class DefaultAppCheckInitializer implements AppCheckInitializer {
  const DefaultAppCheckInitializer();

  @override
  Future<void> activate(AppEnvironment environment) =>
      activateAppCheckForEnvironment(environment);
}

/// Nenhum token de debug é incluído no código ou no Git. Builds de depuração
/// development usam o provider de debug apenas em memória; builds distribuídos
/// usam Play Integrity. O servidor mantém enforcement somente nas callables.
Future<void> activateAppCheckForEnvironment(AppEnvironment environment) async {
  if (environment == AppEnvironment.production || !kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
    );
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidDebugProvider(),
  );
}

Future<FirebaseStartupState> initializeFirebaseForEnvironment({
  required AppEnvironment environment,
  required FirebaseInitializer initializer,
  AppCheckInitializer appCheckInitializer = const DefaultAppCheckInitializer(),
}) async {
  if (environment == AppEnvironment.production) {
    return const FirebaseStartupProductionBlocked();
  }

  try {
    await initializer.initialize();
    await appCheckInitializer.activate(environment);
    return const FirebaseStartupAvailable();
  } on Object {
    return const FirebaseStartupFailure();
  }
}

final Provider<FirebaseStartupState> firebaseStartupProvider =
    Provider<FirebaseStartupState>(
      (Ref ref) => throw StateError('Firebase startup não foi fornecido.'),
    );
