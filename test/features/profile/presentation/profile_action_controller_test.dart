import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('Termos e Política são obrigatórios', () async {
    final _TestContext context = _context();
    addTearDown(context.dispose);

    await context.controller.createProfile(
      displayName: 'Pessoa Teste',
      termsAccepted: false,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: false,
    );

    expect(context.state.status, ProfileActionStatus.failure);
    expect(context.profiles.createCalls, 0);
  });

  test('criação começa com consentimentos opcionais desativados', () async {
    final _TestContext context = _context();
    addTearDown(context.dispose);

    await context.controller.createProfile(
      displayName: '  Pessoa   Teste ',
      termsAccepted: true,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: false,
    );

    expect(context.state.status, ProfileActionStatus.success);
    expect(context.profiles.profile?.displayName, 'Pessoa Teste');
    expect(context.profiles.profile?.aiConsentEnabled, isFalse);
    expect(context.profiles.profile?.analyticsConsentEnabled, isFalse);
  });

  test('perfil existente não é sobrescrito por nova criação', () async {
    final _TestContext context = _context(
      profile: createTestProfile(
        ownerId: 'owner',
        displayName: 'Nome Existente',
        aiConsentEnabled: true,
      ),
    );
    addTearDown(context.dispose);
    final DateTime originalCreatedAt = context.profiles.profile!.createdAt;

    await context.controller.createProfile(
      displayName: 'Outro Nome',
      termsAccepted: true,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: true,
    );

    expect(context.profiles.profile?.displayName, 'Nome Existente');
    expect(context.profiles.profile?.aiConsentEnabled, isTrue);
    expect(context.profiles.profile?.createdAt, originalCreatedAt);
    expect(context.state.message, 'Seu perfil existente foi mantido.');
  });

  test('múltiplos envios simultâneos geram uma criação', () async {
    final _TestContext context = _context();
    addTearDown(context.dispose);
    final Completer<void> barrier = Completer<void>();
    context.profiles.createBarrier = barrier;

    final Future<void> first = context.controller.createProfile(
      displayName: 'Pessoa Teste',
      termsAccepted: true,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: false,
    );
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = context.controller.createProfile(
      displayName: 'Pessoa Teste',
      termsAccepted: true,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: false,
    );
    barrier.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(context.profiles.createCalls, 1);
  });

  test('IA é atualizada sem alterar Analytics nem seu timestamp', () async {
    final _TestContext context = _context(
      profile: createTestProfile(ownerId: 'owner'),
    );
    addTearDown(context.dispose);
    final DateTime analyticsTimestamp =
        context.profiles.profile!.analyticsConsentUpdatedAt;

    await context.controller.updateOptionalConsents(
      aiConsentEnabled: true,
      analyticsConsentEnabled: false,
    );

    expect(context.profiles.profile?.aiConsentEnabled, isTrue);
    expect(context.profiles.profile?.analyticsConsentEnabled, isFalse);
    expect(
      context.profiles.profile?.analyticsConsentUpdatedAt,
      analyticsTimestamp,
    );
  });

  test('Analytics é atualizado sem alterar IA nem seu timestamp', () async {
    final _TestContext context = _context(
      profile: createTestProfile(ownerId: 'owner'),
    );
    addTearDown(context.dispose);
    final DateTime aiTimestamp = context.profiles.profile!.aiConsentUpdatedAt;

    await context.controller.updateOptionalConsents(
      aiConsentEnabled: false,
      analyticsConsentEnabled: true,
    );

    expect(context.profiles.profile?.analyticsConsentEnabled, isTrue);
    expect(context.profiles.profile?.aiConsentEnabled, isFalse);
    expect(context.profiles.profile?.aiConsentUpdatedAt, aiTimestamp);
  });

  test('falha no espelhamento Auth preserva nome salvo no Firestore', () async {
    final _TestContext context = _context(
      profile: createTestProfile(ownerId: 'owner'),
    );
    addTearDown(context.dispose);
    context.auth.failDisplayNameMirror = true;

    await context.controller.updateDisplayName('Nome Atualizado');

    expect(context.profiles.profile?.displayName, 'Nome Atualizado');
    expect(context.state.status, ProfileActionStatus.success);
    expect(context.state.hasPartialFailure, isTrue);
    expect(context.auth.updateDisplayNameCalls, 1);
  });

  test('token não atualizado impede qualquer gravação', () async {
    final _TestContext context = _context();
    addTearDown(context.dispose);
    context.auth.tokenEmailVerified = false;

    await context.controller.createProfile(
      displayName: 'Pessoa Teste',
      termsAccepted: true,
      privacyAccepted: true,
      aiConsentEnabled: false,
      analyticsConsentEnabled: false,
    );

    expect(context.state.status, ProfileActionStatus.failure);
    expect(context.profiles.createCalls, 0);
  });

  test(
    'novo aceite jurídico exige escolhas afirmativas e atualiza versões',
    () async {
      final _TestContext context = _context(
        profile: createTestProfile(
          ownerId: 'owner',
          termsVersion: 'terms-dev-0.9.0',
          privacyVersion: 'privacy-dev-0.9.0',
        ),
      );
      addTearDown(context.dispose);

      await context.controller.acceptCurrentLegalVersions(
        termsAccepted: true,
        privacyAccepted: false,
      );
      expect(context.profiles.acceptLegalCalls, 0);

      await context.controller.acceptCurrentLegalVersions(
        termsAccepted: true,
        privacyAccepted: true,
      );
      expect(context.profiles.acceptLegalCalls, 1);
      expect(context.profiles.profile?.hasCurrentLegalVersions, isTrue);
    },
  );
}

final class _TestContext {
  const _TestContext({
    required this.container,
    required this.auth,
    required this.profiles,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;

  ProfileActionController get controller =>
      container.read(profileActionControllerProvider.notifier);
  ProfileActionState get state =>
      container.read(profileActionControllerProvider);

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
    initialProfile: profile,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(profiles),
    ],
  );
  return _TestContext(container: container, auth: auth, profiles: profiles);
}
