// Intenção: garante que o aceite remoto só reflita leitura server-only própria
// e que toda ausência de identidade confirmada preserve o bloqueio fechado.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_consent.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late _FakeConsentRepository repository;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository(
      initialUser: const AuthUser(id: 'synthetic-owner', emailVerified: true),
    );
    repository = _FakeConsentRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        assistantRemoteConsentRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('inicia fechado e só libera após leitura server-only válida', () async {
    expect(container.read(assistantRemoteConsentControllerProvider), isFalse);

    repository.allowed = true;
    await container
        .read(assistantRemoteConsentControllerProvider.notifier)
        .load();

    expect(container.read(assistantRemoteConsentControllerProvider), isTrue);
    expect(repository.readOwnerIds, <String>['synthetic-owner']);
    expect(auth.refreshIdentityCalls, 1);
  });

  test(
    'revogação persiste false no documento próprio após renovar identidade',
    () async {
      repository.allowed = true;
      await container
          .read(assistantRemoteConsentControllerProvider.notifier)
          .load();

      await container
          .read(assistantRemoteConsentControllerProvider.notifier)
          .setAllowed(false);

      expect(container.read(assistantRemoteConsentControllerProvider), isFalse);
      expect(repository.writes, <({String ownerId, bool allowed})>[
        (ownerId: 'synthetic-owner', allowed: false),
      ]);
      expect(auth.refreshIdentityCalls, 2);
    },
  );

  test(
    'identidade ou e-mail não confirmados não leem nem escrevem consentimento',
    () async {
      auth.emit(const AuthUser(id: 'synthetic-owner', emailVerified: false));

      await expectLater(
        container
            .read(assistantRemoteConsentControllerProvider.notifier)
            .setAllowed(true),
        throwsA(isA<StateError>()),
      );

      expect(repository.readOwnerIds, isEmpty);
      expect(repository.writes, isEmpty);
      expect(container.read(assistantRemoteConsentControllerProvider), isFalse);
    },
  );
}

/// Implementa somente o contrato local para impedir acesso Firebase nos testes.
final class _FakeConsentRepository implements AssistantRemoteConsentRepository {
  bool allowed = false;
  final List<String> readOwnerIds = <String>[];
  final List<({String ownerId, bool allowed})> writes =
      <({String ownerId, bool allowed})>[];

  @override
  Future<bool> readOwnConsent({required String ownerId}) async {
    readOwnerIds.add(ownerId);
    return allowed;
  }

  @override
  Future<void> setOwnConsent({
    required String ownerId,
    required bool financialContextAllowed,
  }) async {
    writes.add((ownerId: ownerId, allowed: financialContextAllowed));
    allowed = financialContextAllowed;
  }
}
