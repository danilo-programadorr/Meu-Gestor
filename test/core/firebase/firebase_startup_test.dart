import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';

void main() {
  group('initializeFirebaseForEnvironment', () {
    test('inicializa Firebase em development', () async {
      final _FakeInitializer initializer = _FakeInitializer();

      final FirebaseStartupState result =
          await initializeFirebaseForEnvironment(
            environment: AppEnvironment.development,
            initializer: initializer,
            appCheckInitializer: _FakeAppCheckInitializer(),
          );

      expect(result, isA<FirebaseStartupAvailable>());
      expect(initializer.calls, 1);
    });

    test('retorna falha tipada sem propagar detalhes', () async {
      final _FakeInitializer initializer = _FakeInitializer(shouldFail: true);

      final FirebaseStartupState result =
          await initializeFirebaseForEnvironment(
            environment: AppEnvironment.development,
            initializer: initializer,
            appCheckInitializer: _FakeAppCheckInitializer(),
          );

      expect(result, isA<FirebaseStartupFailure>());
      expect(initializer.calls, 1);
    });

    test(
      'bloqueia production sem chamar o inicializador development',
      () async {
        final _FakeInitializer initializer = _FakeInitializer();

        final FirebaseStartupState result =
            await initializeFirebaseForEnvironment(
              environment: AppEnvironment.production,
              initializer: initializer,
              appCheckInitializer: _FakeAppCheckInitializer(),
            );

        expect(result, isA<FirebaseStartupProductionBlocked>());
        expect(initializer.calls, 0);
      },
    );
  });
}

final class _FakeInitializer implements FirebaseInitializer {
  _FakeInitializer({this.shouldFail = false});

  final bool shouldFail;
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls += 1;
    if (shouldFail) {
      throw StateError('detalhe técnico não deve chegar à interface');
    }
  }
}

final class _FakeAppCheckInitializer implements AppCheckInitializer {
  @override
  Future<void> activate(AppEnvironment environment) async {}
}
