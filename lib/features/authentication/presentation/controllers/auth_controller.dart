import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';

final NotifierProvider<AuthController, AuthActionState> authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(AuthController.new);

final class AuthController extends Notifier<AuthActionState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthActionState build() => const AuthActionState.idle();

  void clearMessage() {
    if (!state.isLoading) {
      state = const AuthActionState.idle();
    }
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    await _execute(
      () => _repository.createAccount(
        name: name,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> refreshVerification() async {
    if (state.isLoading) {
      return;
    }
    state = const AuthActionState.loading();
    try {
      final AuthUser? user = await _repository.reloadCurrentUser();
      state = AuthActionState.success(
        message: user?.emailVerified == true
            ? 'Email confirmado com sucesso.'
            : 'A confirmação ainda não foi identificada.',
      );
    } on AuthFailure catch (failure) {
      state = AuthActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const AuthActionState.failure(
        message: 'Não foi possível atualizar a confirmação agora.',
      );
    }
  }

  Future<void> resendVerification() async {
    await _execute(
      _repository.sendEmailVerification,
      successMessage: 'Um novo email de confirmação foi enviado.',
    );
  }

  Future<void> resetPassword({required String email}) async {
    await _execute(
      () => _repository.sendPasswordResetEmail(email: email),
      successMessage:
          'Se houver uma conta associada a este email, enviaremos as '
          'instruções de redefinição.',
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _execute(
      () => _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    if (state.isLoading) {
      return;
    }
    state = const AuthActionState.loading();
    try {
      final GoogleAuthOutcome outcome = await _repository.signInWithGoogle();
      state = switch (outcome) {
        GoogleAuthOutcome.success => const AuthActionState.success(),
        GoogleAuthOutcome.cancelled => const AuthActionState.cancelled(
          message: 'A entrada com Google foi cancelada.',
        ),
      };
    } on AuthFailure catch (failure) {
      state = AuthActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const AuthActionState.failure(
        message: 'Não foi possível entrar com o Google agora.',
      );
    }
  }

  Future<void> signOut() async {
    await _execute(_repository.signOut);
  }

  Future<void> _execute(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (state.isLoading) {
      return;
    }
    state = const AuthActionState.loading();
    try {
      await action();
      state = AuthActionState.success(message: successMessage);
    } on AuthFailure catch (failure) {
      state = AuthActionState.failure(message: failure.safeMessage);
    } on Object {
      state = const AuthActionState.failure(
        message: 'Não foi possível concluir a operação. Tente novamente.',
      );
    }
  }
}
