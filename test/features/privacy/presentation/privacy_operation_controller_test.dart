import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_contract.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/privacy_operation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  ProviderContainer container({
    required FakeAuthRepository auth,
    PrivacyOperationRepository? repository,
    PrivacyLocalCleanupCoordinator? cleanup,
  }) => ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      if (repository != null)
        privacyOperationRepositoryProvider.overrideWithValue(repository),
      if (cleanup != null)
        privacyLocalCleanupCoordinatorProvider.overrideWithValue(cleanup),
    ],
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

  test(
    'só publica conclusão e limpa estado local após recibo do servidor',
    () async {
      final FakeAuthRepository auth = FakeAuthRepository(
        initialUser: const AuthUser(
          id: 'synthetic-user',
          displayName: 'Synthetic',
          email: 'synthetic@example.invalid',
          emailVerified: true,
        ),
      );
      final _CompletingPrivacyRepository repository =
          _CompletingPrivacyRepository();
      final _RecordingCleanup cleanup = _RecordingCleanup();
      final ProviderContainer value = container(
        auth: auth,
        repository: repository,
        cleanup: cleanup,
      );
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
        PrivacyUiStatus.completed,
      );
      expect(repository.retryCalls, 1);
      expect(cleanup.calls, <String>['financialReset:synthetic-user']);
    },
  );

  test(
    'limpeza local distingue reset financeiro de exclusão da conta',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'appearance.theme_mode': 'dark',
        'calendar_recurrences_v1_synthetic-user': <String>['recurrence'],
        'android_calendar_selection_v1_synthetic-user': <String>['calendar'],
        'assistant_introduction_v1_synthetic-user': true,
        'assistant_personalization_v1_synthetic-user.mode': 'customName',
        'assistant_personalization_v1_synthetic-user.customName': 'Pessoa',
      });
      const SharedPreferencesPrivacyLocalCleanupCoordinator coordinator =
          SharedPreferencesPrivacyLocalCleanupCoordinator();
      await coordinator.cleanAfterServerConfirmation(
        type: PrivacyOperationType.financialReset,
        ownerId: 'synthetic-user',
      );
      SharedPreferences preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey('calendar_recurrences_v1_synthetic-user'),
        isFalse,
      );
      expect(preferences.getString('appearance.theme_mode'), 'dark');
      expect(
        preferences.getBool('assistant_introduction_v1_synthetic-user'),
        isTrue,
      );
      await coordinator.cleanAfterServerConfirmation(
        type: PrivacyOperationType.accountDeletion,
        ownerId: 'synthetic-user',
      );
      preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey('android_calendar_selection_v1_synthetic-user'),
        isFalse,
      );
      expect(
        preferences.containsKey('assistant_introduction_v1_synthetic-user'),
        isFalse,
      );
      expect(
        preferences.containsKey(
          'assistant_personalization_v1_synthetic-user.mode',
        ),
        isFalse,
      );
      expect(preferences.getString('appearance.theme_mode'), 'dark');
    },
  );
}

final class _CompletingPrivacyRepository implements PrivacyOperationRepository {
  int retryCalls = 0;
  final PrivacyOperationId id = PrivacyOperationId(
    'privacy-operation-synthetic-0001',
  );

  @override
  Future<PrivacyOperationSnapshot> request(
    PrivacyOperationStartCommand command,
  ) async => PrivacyOperationSnapshot.active(
    PrivacyOperation(
      id: id,
      type: command.type,
      ownerId: 'synthetic-user',
      state: PrivacyOperationState.prepared,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 18),
      updatedAt: DateTime.utc(2026, 10, 18),
    ),
  );

  @override
  Future<PrivacyOperationSnapshot> retry(PrivacyOperationId operationId) async {
    retryCalls += 1;
    return PrivacyOperationSnapshot.completed(
      operationId: id,
      type: PrivacyOperationType.financialReset,
      receipt: AnonymousPrivacyReceipt.create(
        receiptId: 'privacy-receipt-synthetic-0001',
        type: PrivacyOperationType.financialReset,
        result: PrivacyOperationResult.resetCompleted,
        completedAt: DateTime.utc(2026, 10, 18),
      ),
    );
  }

  @override
  Future<PrivacyOperationSnapshot> status(PrivacyOperationId operationId) =>
      throw StateError('status should not be called after completion');
}

final class _RecordingCleanup implements PrivacyLocalCleanupCoordinator {
  final List<String> calls = <String>[];

  @override
  Future<void> cleanAfterServerConfirmation({
    required PrivacyOperationType type,
    required String ownerId,
  }) async {
    calls.add('${type.name}:$ownerId');
  }
}
