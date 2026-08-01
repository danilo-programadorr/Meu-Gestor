import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/google_auth_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';

final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required AppEnvironment environment,
    AuthDiagnosticWriter? diagnosticWriter,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn,
       _googleInitializer = GoogleSignInInitializer(googleSignIn.initialize),
       _googleDiagnostics = GoogleAuthDiagnostics(
         environment: environment,
         writer: diagnosticWriter,
       );

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final GoogleSignInInitializer _googleInitializer;
  final GoogleAuthDiagnostics _googleDiagnostics;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.userChanges().map(_mapUser);
  }

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final User? user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          kind: AuthFailureKind.missingCredential,
          safeMessage: 'Não foi possível concluir a criação da conta.',
        );
      }
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      return _mapUser(_firebaseAuth.currentUser);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<AuthVerificationSnapshot> forceRefreshIdentityToken() async {
    try {
      final User? refreshed = _firebaseAuth.currentUser;
      if (refreshed == null) {
        return const AuthVerificationSnapshot(
          user: null,
          tokenEmailVerified: false,
        );
      }
      final IdTokenResult token = await refreshed.getIdTokenResult(true);
      return AuthVerificationSnapshot(
        user: _mapUser(refreshed),
        tokenEmailVerified: token.claims?['email_verified'] == true,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthFailure(
          kind: AuthFailureKind.missingCredential,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        );
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<GoogleAuthOutcome> signInWithGoogle() async {
    try {
      await _googleInitializer.ensureInitialized();
    } on GoogleSignInException catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.initialization,
        error: error,
      );
      throw GoogleAuthFailureMapper.fromGoogleSignIn(error);
    } on Object catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.initialization,
        error: error,
      );
      throw GoogleAuthFailureMapper.unknown;
    }

    late final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.authentication,
        error: error,
      );
      if (GoogleAuthFailureMapper.isCancellation(error)) {
        return GoogleAuthOutcome.cancelled;
      }
      throw GoogleAuthFailureMapper.fromGoogleSignIn(error);
    } on Object catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.authentication,
        error: error,
      );
      throw GoogleAuthFailureMapper.unknown;
    }

    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _googleDiagnostics.recordMissingCredential();
      throw GoogleAuthFailureMapper.missingCredential;
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );
    try {
      await _firebaseAuth.signInWithCredential(credential);
      return GoogleAuthOutcome.success;
    } on FirebaseAuthException catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.firebaseAuthentication,
        error: error,
      );
      throw GoogleAuthFailureMapper.fromFirebase(error);
    } on Object catch (error) {
      _googleDiagnostics.record(
        stage: GoogleAuthStage.firebaseAuthentication,
        error: error,
      );
      throw GoogleAuthFailureMapper.unknown;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthFailure(
          kind: AuthFailureKind.missingCredential,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        );
      }
      await user.updateDisplayName(displayName);
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseFailure(error);
    }
  }

  static AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(
      id: user.uid,
      displayName: user.displayName,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }

  static AuthFailure _mapFirebaseFailure(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => const AuthFailure(
        kind: AuthFailureKind.invalidEmail,
        safeMessage: 'O email informado não é válido.',
      ),
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' => const AuthFailure(
        kind: AuthFailureKind.invalidCredentials,
        safeMessage: 'Não foi possível entrar com os dados informados.',
      ),
      'weak-password' => const AuthFailure(
        kind: AuthFailureKind.weakPassword,
        safeMessage:
            'A senha informada não atende aos requisitos de segurança.',
      ),
      'email-already-in-use' => const AuthFailure(
        kind: AuthFailureKind.accountCreation,
        safeMessage: 'Não foi possível criar a conta com os dados informados.',
      ),
      'network-request-failed' => const AuthFailure(
        kind: AuthFailureKind.network,
        safeMessage: 'Verifique sua conexão e tente novamente.',
      ),
      'too-many-requests' => const AuthFailure(
        kind: AuthFailureKind.tooManyRequests,
        safeMessage:
            'Muitas tentativas foram feitas. Aguarde e tente novamente.',
      ),
      'operation-not-allowed' => const AuthFailure(
        kind: AuthFailureKind.operationNotAllowed,
        safeMessage: 'Esta forma de acesso não está disponível no momento.',
      ),
      _ => const AuthFailure(
        kind: AuthFailureKind.unknown,
        safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      ),
    };
  }
}
