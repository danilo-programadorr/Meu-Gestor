import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';

typedef AuthDiagnosticWriter = void Function(String message);

enum GoogleAuthStage {
  initialization,
  authentication,
  idToken,
  firebaseAuthentication,
}

final class GoogleAuthDiagnostics {
  GoogleAuthDiagnostics({
    required AppEnvironment environment,
    AuthDiagnosticWriter? writer,
  }) : _enabled = environment == AppEnvironment.development,
       _writer = writer ?? debugPrint;

  final bool _enabled;
  final AuthDiagnosticWriter _writer;

  void record({required GoogleAuthStage stage, required Object error}) {
    if (!_enabled) {
      return;
    }

    final String googleCode = error is GoogleSignInException
        ? error.code.name
        : 'none';
    final String firebaseCode = error is FirebaseAuthException
        ? error.code
        : 'none';
    _writer(
      'GoogleAuthDiagnostic('
      'stage=${stage.name}, '
      'exceptionType=${error.runtimeType}, '
      'googleCode=$googleCode, '
      'firebaseCode=$firebaseCode)',
    );
  }

  void recordMissingCredential() {
    if (!_enabled) {
      return;
    }

    _writer(
      'GoogleAuthDiagnostic('
      'stage=${GoogleAuthStage.idToken.name}, '
      'exceptionType=MissingGoogleCredential, '
      'googleCode=none, '
      'firebaseCode=none)',
    );
  }
}

abstract final class GoogleAuthFailureMapper {
  static const String safeMessage =
      'Não foi possível entrar com o Google agora.';

  static bool isCancellation(GoogleSignInException error) {
    return error.code == GoogleSignInExceptionCode.canceled;
  }

  static AuthFailure fromGoogleSignIn(GoogleSignInException error) {
    final AuthFailureKind kind = switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError ||
      GoogleSignInExceptionCode.uiUnavailable =>
        AuthFailureKind.googleClientConfiguration,
      GoogleSignInExceptionCode.interrupted =>
        AuthFailureKind.googleAuthentication,
      GoogleSignInExceptionCode.userMismatch =>
        AuthFailureKind.googleAuthentication,
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.unknownError => AuthFailureKind.unknown,
    };
    return AuthFailure(kind: kind, safeMessage: safeMessage);
  }

  static AuthFailure fromFirebase(FirebaseAuthException error) {
    return AuthFailure(
      kind: error.code == 'network-request-failed'
          ? AuthFailureKind.network
          : AuthFailureKind.firebaseAuthentication,
      safeMessage: safeMessage,
    );
  }

  static const AuthFailure missingCredential = AuthFailure(
    kind: AuthFailureKind.missingCredential,
    safeMessage: safeMessage,
  );

  static const AuthFailure unknown = AuthFailure(
    kind: AuthFailureKind.unknown,
    safeMessage: safeMessage,
  );
}

final class GoogleSignInInitializer {
  GoogleSignInInitializer(Future<void> Function() initialize)
    : _initialize = initialize;

  final Future<void> Function() _initialize;
  Future<void>? _initialization;

  Future<void> ensureInitialized() {
    return _initialization ??= _initialize();
  }
}
