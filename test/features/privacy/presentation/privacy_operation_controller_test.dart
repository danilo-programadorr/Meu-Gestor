import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/privacy_operation_controller.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  ProviderContainer container({required FakeAuthRepository auth}) =>
      ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );

  test('frase incorreta falha antes de reautenticar', () async {
    final FakeAuthRepository auth = FakeAuthRepository(
      initialUser: const AuthUser(
        id: 'synthetic-user',
        displayName: 'Synthetic',
        email: 'synthetic@example.invalid',
        emailVerified: true,
      ),
    );
    final ProviderContainer value = container(auth: auth);
    addTearDown(value.dispose);
    await value
        .read(privacyOperationControllerProvider.notifier)
        .submit(
          type: PrivacyOperationType.financialReset,
          phrase: 'RESETAR',
          method: PrivacyReauthenticationMethod.password,
          password: 'synthetic-password',
        );
    expect(auth.reauthenticatePasswordCalls, 0);
    expect(
      value.read(privacyOperationControllerProvider).status,
      PrivacyUiStatus.recoverableFailure,
    );
  });

  test('senha incorreta e sessão perdida não iniciam operação', () async {
    final FakeAuthRepository auth = FakeAuthRepository()
      ..nextFailure = const AuthFailure(
        kind: AuthFailureKind.invalidCredentials,
        safeMessage: 'A senha informada não está correta.',
      );
    final ProviderContainer value = container(auth: auth);
    addTearDown(value.dispose);
    await value
        .read(privacyOperationControllerProvider.notifier)
        .submit(
          type: PrivacyOperationType.accountDeletion,
          phrase: 'EXCLUIR MINHA CONTA',
          method: PrivacyReauthenticationMethod.password,
          password: 'synthetic-password',
        );
    expect(
      value.read(privacyOperationControllerProvider).status,
      PrivacyUiStatus.recoverableFailure,
    );
    auth.tokenEmailVerified = false;
    await value
        .read(privacyOperationControllerProvider.notifier)
        .submit(
          type: PrivacyOperationType.accountDeletion,
          phrase: 'EXCLUIR MINHA CONTA',
          method: PrivacyReauthenticationMethod.google,
        );
    expect(
      value.read(privacyOperationControllerProvider).status,
      PrivacyUiStatus.sessionLost,
    );
  });

  test('indisponibilidade do backend nunca publica sucesso local', () async {
    final FakeAuthRepository auth = FakeAuthRepository(
      initialUser: const AuthUser(
        id: 'synthetic-user',
        displayName: 'Synthetic',
        email: 'synthetic@example.invalid',
        emailVerified: true,
      ),
    );
    final ProviderContainer value = container(auth: auth);
    addTearDown(value.dispose);
    await value
        .read(privacyOperationControllerProvider.notifier)
        .submit(
          type: PrivacyOperationType.financialReset,
          phrase: 'RESETAR DADOS FINANCEIROS',
          method: PrivacyReauthenticationMethod.password,
          password: 'synthetic-password',
        );
    expect(
      value.read(privacyOperationControllerProvider).status,
      PrivacyUiStatus.recoverableFailure,
    );
  });
}
