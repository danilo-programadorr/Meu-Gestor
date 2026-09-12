// Intenção: mantém a conversa bloqueada até que os dois consentimentos sejam
// gravados e confirmados, inclusive após falhas parciais ou recusa explícita.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_consent.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_conversation_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test(
    'ausência ou revogação mantém a decisão pendente e não lê remoto',
    () async {
      final _TestContext context = _context();
      addTearDown(context.dispose);

      await context.controller.check(aiConsentEnabled: false);

      expect(context.state.phase, AssistantConversationConsentPhase.required);
      expect(context.remote.readOwnerIds, isEmpty);
      expect(context.state.isReady, isFalse);
    },
  );

  test('consentimento remoto inválido mantém a decisão pendente', () async {
    final _TestContext context = _context(
      profile: createTestProfile(ownerId: 'owner', aiConsentEnabled: true),
    );
    addTearDown(context.dispose);

    await context.controller.check(aiConsentEnabled: true);

    expect(context.state.phase, AssistantConversationConsentPhase.required);
    expect(context.remote.readOwnerIds, <String>['owner']);
    expect(context.state.isReady, isFalse);
  });

  test(
    'aceite grava o consentimento geral e o remoto canônico antes de liberar',
    () async {
      final UserProfile profile = createTestProfile(
        ownerId: 'owner',
        aiConsentEnabled: false,
      );
      final _TestContext context = _context(profile: profile);
      addTearDown(context.dispose);

      await context.controller.activate(profile: profile);

      expect(context.profiles.profile?.aiConsentEnabled, isTrue);
      expect(context.remote.writes, <({String ownerId, bool allowed})>[
        (ownerId: 'owner', allowed: true),
      ]);
      expect(context.state.phase, AssistantConversationConsentPhase.ready);
      expect(context.state.isReady, isTrue);
    },
  );

  test(
    'falha de gravação não libera a conversa nem grava o aceite remoto',
    () async {
      final UserProfile profile = createTestProfile(
        ownerId: 'owner',
        aiConsentEnabled: false,
      );
      final _TestContext context = _context(profile: profile);
      addTearDown(context.dispose);
      context.profiles.nextFailure = const UserProfileFailure(
        kind: UserProfileFailureKind.unavailable,
        safeMessage: 'Indisponível.',
      );

      await context.controller.activate(profile: profile);

      expect(context.state.phase, AssistantConversationConsentPhase.failed);
      expect(context.state.isReady, isFalse);
      expect(context.remote.writes, isEmpty);
    },
  );

  test('recusa fecha apenas a decisão e conserva o bloqueio remoto', () async {
    final _TestContext context = _context();
    addTearDown(context.dispose);

    context.controller.decline();

    expect(context.state.phase, AssistantConversationConsentPhase.declined);
    expect(context.state.isReady, isFalse);
    expect(context.remote.writes, isEmpty);
  });
}

final class _TestContext {
  const _TestContext({
    required this.container,
    required this.auth,
    required this.profiles,
    required this.remote,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;
  final _FakeConsentRepository remote;

  AssistantConversationConsentController get controller =>
      container.read(assistantConversationConsentControllerProvider.notifier);
  AssistantConversationConsentState get state =>
      container.read(assistantConversationConsentControllerProvider);

  void dispose() {
    container.dispose();
    unawaited(auth.close());
  }
}

_TestContext _context({UserProfile? profile}) {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeUserProfileRepository profiles = FakeUserProfileRepository(
    initialProfile: profile ?? createTestProfile(ownerId: 'owner'),
  );
  final _FakeConsentRepository remote = _FakeConsentRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(profiles),
      assistantRemoteConsentRepositoryProvider.overrideWithValue(remote),
    ],
  );
  return _TestContext(
    container: container,
    auth: auth,
    profiles: profiles,
    remote: remote,
  );
}

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
