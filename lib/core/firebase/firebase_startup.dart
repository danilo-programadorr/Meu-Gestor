import 'package:firebase_core/firebase_core.dart';
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

final class DefaultFirebaseInitializer implements FirebaseInitializer {
  const DefaultFirebaseInitializer();

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
  }
}

Future<FirebaseStartupState> initializeFirebaseForEnvironment({
  required AppEnvironment environment,
  required FirebaseInitializer initializer,
}) async {
  if (environment == AppEnvironment.production) {
    return const FirebaseStartupProductionBlocked();
  }

  try {
    await initializer.initialize();
    return const FirebaseStartupAvailable();
  } on Object {
    return const FirebaseStartupFailure();
  }
}

final Provider<FirebaseStartupState> firebaseStartupProvider =
    Provider<FirebaseStartupState>(
      (Ref ref) => throw StateError('Firebase startup não foi fornecido.'),
    );
