import 'dart:async';

import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  AuthFailure? nextFailure;
  GoogleAuthOutcome googleOutcome = GoogleAuthOutcome.success;
  Completer<void>? signInBarrier;

  int signInCalls = 0;
  int createAccountCalls = 0;
  int googleCalls = 0;
  int resetCalls = 0;
  int resendCalls = 0;
  int reloadCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  Future<void> close() => _controller.close();

  void emit(AuthUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    createAccountCalls += 1;
    _throwIfNeeded();
    emit(
      AuthUser(
        id: 'created-user',
        displayName: name,
        email: email,
        emailVerified: false,
      ),
    );
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCalls += 1;
    _throwIfNeeded();
    return _user;
  }

  @override
  Future<void> sendEmailVerification() async {
    resendCalls += 1;
    _throwIfNeeded();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCalls += 1;
    _throwIfNeeded();
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    final Completer<void>? barrier = signInBarrier;
    if (barrier != null) {
      await barrier.future;
    }
    _throwIfNeeded();
  }

  @override
  Future<GoogleAuthOutcome> signInWithGoogle() async {
    googleCalls += 1;
    _throwIfNeeded();
    return googleOutcome;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _throwIfNeeded();
    emit(null);
  }

  void _throwIfNeeded() {
    final AuthFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }
}
