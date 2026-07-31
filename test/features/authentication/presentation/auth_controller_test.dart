import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    await repository.close();
  });

  test('traduz falha de login para mensagem segura', () async {
    repository.nextFailure = const AuthFailure(
      kind: AuthFailureKind.invalidCredentials,
      safeMessage: 'Não foi possível entrar com os dados informados.',
    );

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'pessoa@exemplo.com', password: 'Senha123');

    final AuthActionState state = container.read(authControllerProvider);
    expect(state.status, AuthActionStatus.failure);
    expect(state.message, 'Não foi possível entrar com os dados informados.');
  });

  test('impede tentativa duplicada durante carregamento', () async {
    final Completer<void> barrier = Completer<void>();
    repository.signInBarrier = barrier;
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    final Future<void> first = controller.signIn(
      email: 'pessoa@exemplo.com',
      password: 'Senha123',
    );
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.signIn(
      email: 'pessoa@exemplo.com',
      password: 'Senha123',
    );

    expect(repository.signInCalls, 1);
    expect(container.read(authControllerProvider).isLoading, isTrue);
    barrier.complete();
    await Future.wait(<Future<void>>[first, second]);
  });

  test('recuperação sempre usa resposta genérica', () async {
    await container
        .read(authControllerProvider.notifier)
        .resetPassword(email: 'pessoa@exemplo.com');

    expect(repository.resetCalls, 1);
    expect(
      container.read(authControllerProvider).message,
      'Se houver uma conta associada a este email, enviaremos as instruções de redefinição.',
    );
  });

  test('trata cancelamento Google como estado informativo', () async {
    repository.googleOutcome = GoogleAuthOutcome.cancelled;

    await container.read(authControllerProvider.notifier).signInWithGoogle();

    expect(
      container.read(authControllerProvider).status,
      AuthActionStatus.cancelled,
    );
    expect(repository.googleCalls, 1);
  });

  test('trata sucesso Google', () async {
    await container.read(authControllerProvider.notifier).signInWithGoogle();

    expect(
      container.read(authControllerProvider).status,
      AuthActionStatus.success,
    );
  });

  test('reenvia confirmação, atualiza estado e encerra sessão', () async {
    repository.emit(
      const AuthUser(
        id: 'user',
        email: 'pessoa@exemplo.com',
        emailVerified: false,
      ),
    );
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    await controller.resendVerification();
    expect(repository.resendCalls, 1);
    await controller.refreshVerification();
    expect(repository.reloadCalls, 1);
    await controller.signOut();
    expect(repository.signOutCalls, 1);
  });
}
