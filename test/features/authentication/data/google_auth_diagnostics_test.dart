import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/google_auth_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';

void main() {
  group('GoogleAuthFailureMapper', () {
    test('diferencia cancelamento de falha real', () {
      const GoogleSignInException error = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(GoogleAuthFailureMapper.isCancellation(error), isTrue);
    });

    test('mapeia configuração, interrupção e erro desconhecido', () {
      expect(
        GoogleAuthFailureMapper.fromGoogleSignIn(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
        ).kind,
        AuthFailureKind.googleClientConfiguration,
      );
      expect(
        GoogleAuthFailureMapper.fromGoogleSignIn(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        ).kind,
        AuthFailureKind.googleAuthentication,
      );
      expect(
        GoogleAuthFailureMapper.fromGoogleSignIn(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
          ),
        ).kind,
        AuthFailureKind.unknown,
      );
    });

    test('diferencia rede de falha do Firebase Authentication', () {
      expect(
        GoogleAuthFailureMapper.fromFirebase(
          FirebaseAuthException(code: 'network-request-failed'),
        ).kind,
        AuthFailureKind.network,
      );
      expect(
        GoogleAuthFailureMapper.fromFirebase(
          FirebaseAuthException(code: 'invalid-credential'),
        ).kind,
        AuthFailureKind.firebaseAuthentication,
      );
    });
  });

  group('GoogleAuthDiagnostics', () {
    test('development registra somente campos sanitizados', () {
      final List<String> messages = <String>[];
      final GoogleAuthDiagnostics diagnostics = GoogleAuthDiagnostics(
        environment: AppEnvironment.development,
        writer: messages.add,
      );
      const GoogleSignInException error = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'client-id-nao-pode-aparecer',
        details: 'token-nao-pode-aparecer',
      );

      diagnostics.record(stage: GoogleAuthStage.authentication, error: error);

      expect(messages, hasLength(1));
      expect(messages.single, contains('stage=authentication'));
      expect(messages.single, contains('GoogleSignInException'));
      expect(messages.single, contains('clientConfigurationError'));
      expect(messages.single, isNot(contains(error.description)));
      expect(messages.single, isNot(contains(error.details.toString())));
    });

    test('production não registra diagnóstico', () {
      final List<String> messages = <String>[];
      final GoogleAuthDiagnostics diagnostics = GoogleAuthDiagnostics(
        environment: AppEnvironment.production,
        writer: messages.add,
      );

      diagnostics.record(
        stage: GoogleAuthStage.firebaseAuthentication,
        error: FirebaseAuthException(code: 'invalid-credential'),
      );
      diagnostics.recordMissingCredential();

      expect(messages, isEmpty);
    });
  });

  test('GoogleSignInInitializer inicializa exatamente uma vez', () async {
    int calls = 0;
    final GoogleSignInInitializer initializer = GoogleSignInInitializer(
      () async {
        calls += 1;
      },
    );

    await initializer.ensureInitialized();
    await initializer.ensureInitialized();

    expect(calls, 1);
  });
}
