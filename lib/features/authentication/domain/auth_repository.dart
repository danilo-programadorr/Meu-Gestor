import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  Future<GoogleAuthOutcome> signInWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> sendEmailVerification();

  Future<AuthUser?> reloadCurrentUser();

  Future<AuthVerificationSnapshot> forceRefreshIdentityToken();

  Future<void> updateDisplayName(String displayName);

  Future<void> signOut();
}

final class AuthVerificationSnapshot {
  const AuthVerificationSnapshot({
    required this.user,
    required this.tokenEmailVerified,
  });

  final AuthUser? user;
  final bool tokenEmailVerified;

  bool get isFullyVerified => user?.emailVerified == true && tokenEmailVerified;
}
