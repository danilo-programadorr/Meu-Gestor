import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('usuário não autenticado não consulta Firestore', () async {
    final _GateContext context = _context(FakeAuthRepository());
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateUnauthenticated>());
    expect(context.profiles.readCalls, 0);
  });

  test('usuário não verificado não consulta Firestore', () async {
    final _GateContext context = _context(
      FakeAuthRepository(
        initialUser: const AuthUser(id: 'owner', emailVerified: false),
      ),
    );
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateUnverifiedEmail>());
    expect(context.auth.reloadCalls, 0);
    expect(context.profiles.readCalls, 0);
  });

  test('token sem email_verified bloqueia Firestore', () async {
    final FakeAuthRepository auth = _verifiedAuth()..tokenEmailVerified = false;
    final _GateContext context = _context(auth);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateUnverifiedEmail>());
    expect(auth.reloadCalls, 1);
    expect(auth.refreshIdentityCalls, 1);
    expect(context.profiles.readCalls, 0);
  });

  test(
    'usuário Google verificado sem perfil termina em profileMissing',
    () async {
      final _GateContext context = _context(_verifiedAuth());
      addTearDown(context.dispose);

      final ProfileGateState state = await _terminalState(context.container);

      expect(state, isA<ProfileGateMissing>());
      expect(
        (state as ProfileGateMissing).suggestedDisplayName,
        'Pessoa Teste',
      );
      expect(context.profiles.readCalls, 1);
    },
  );

  test('perfil válido libera área autenticada', () async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository(
      initialProfile: createTestProfile(ownerId: 'owner'),
    );
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateValid>());
  });

  test('versão jurídica antiga exige novo aceite', () async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository(
      initialProfile: createTestProfile(
        ownerId: 'owner',
        termsVersion: 'terms-dev-0.9.0',
      ),
    );
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateLegalUpdateRequired>());
  });

  test('cache ou escrita pendente não libera o perfil', () async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository(
      initialProfile: createTestProfile(ownerId: 'owner'),
    )..serverConfirmed = false;
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateFailure>());
    expect(
      (state as ProfileGateFailure).failure.code,
      'PROFILE_SERVER_CONFIRMATION_REQUIRED',
    );
  });

  test('permissão negada produz falha segura e retry funciona', () async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository()
      ..nextFailure = const UserProfileFailure(
        kind: UserProfileFailureKind.permissionDenied,
        safeMessage: 'Não foi possível acessar seu perfil com segurança.',
      );
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState first = await _terminalState(context.container);
    expect(first, isA<ProfileGateFailure>());
    expect(
      (first as ProfileGateFailure).failure.code,
      'PROFILE_PERMISSION_DENIED',
    );

    profiles.profile = createTestProfile(ownerId: 'owner');
    await context.container
        .read(profileGateControllerProvider.notifier)
        .retry();

    expect(
      context.container.read(profileGateControllerProvider).value,
      isA<ProfileGateValid>(),
    );
  });

  for (final UserProfileFailure failure in <UserProfileFailure>[
    const UserProfileFailure(
      kind: UserProfileFailureKind.unavailable,
      safeMessage: 'Seu perfil está temporariamente indisponível.',
    ),
    const UserProfileFailure(
      kind: UserProfileFailureKind.timeout,
      safeMessage: 'A operação demorou demais.',
    ),
  ]) {
    test('${failure.kind.name} produz erro recuperável', () async {
      final FakeUserProfileRepository profiles = FakeUserProfileRepository()
        ..nextFailure = failure;
      final _GateContext context = _context(
        _verifiedAuth(),
        profiles: profiles,
      );
      addTearDown(context.dispose);

      final ProfileGateState state = await _terminalState(context.container);

      expect(state, isA<ProfileGateFailure>());
      expect((state as ProfileGateFailure).failure.kind, failure.kind);

      profiles.profile = createTestProfile(ownerId: 'owner');
      await context.container
          .read(profileGateControllerProvider.notifier)
          .retry();
      expect(
        context.container.read(profileGateControllerProvider).value,
        isA<ProfileGateValid>(),
      );
    });
  }

  for (final UserProfileFailure failure in <UserProfileFailure>[
    const UserProfileFailure(
      kind: UserProfileFailureKind.conversion,
      safeMessage: 'Encontramos uma inconsistência no seu perfil.',
    ),
    const UserProfileFailure(
      kind: UserProfileFailureKind.incompatible,
      safeMessage: 'Encontramos uma inconsistência no seu perfil.',
    ),
  ]) {
    test('${failure.kind.name} produz perfil incompatível', () async {
      final FakeUserProfileRepository profiles = FakeUserProfileRepository()
        ..nextFailure = failure;
      final _GateContext context = _context(
        _verifiedAuth(),
        profiles: profiles,
      );
      addTearDown(context.dispose);

      final ProfileGateState state = await _terminalState(context.container);

      expect(state, isA<ProfileGateIncompatible>());
      expect(
        (state as ProfileGateIncompatible).failure.code,
        'PROFILE_DATA_INVALID',
      );
    });
  }

  test('reload que nunca conclui termina por timeout recuperável', () async {
    final FakeAuthRepository auth = _verifiedAuth()
      ..reloadBarrier = Completer<void>();
    final _GateContext context = _context(auth);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateFailure>());
    expect((state as ProfileGateFailure).failure.code, 'PROFILE_GATE_TIMEOUT');
    expect(auth.refreshIdentityCalls, 0);
    expect(context.profiles.readCalls, 0);
  });

  test('token que nunca conclui termina por timeout sem ler perfil', () async {
    final FakeAuthRepository auth = _verifiedAuth()
      ..tokenBarrier = Completer<void>();
    final _GateContext context = _context(auth);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateFailure>());
    expect((state as ProfileGateFailure).failure.code, 'PROFILE_GATE_TIMEOUT');
    expect(context.profiles.readCalls, 0);
  });

  test('leitura Firestore que nunca conclui termina por timeout', () async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository()
      ..readBarrier = Completer<void>();
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateFailure>());
    expect((state as ProfileGateFailure).failure.code, 'PROFILE_GATE_TIMEOUT');
    expect(state.isTerminal, isTrue);
  });

  test('usuário nulo após reload retorna ao login sem ler perfil', () async {
    final FakeAuthRepository auth = _verifiedAuth()
      ..clearUserDuringReload = true;
    final _GateContext context = _context(auth);
    addTearDown(context.dispose);

    final ProfileGateState state = await _terminalState(context.container);

    expect(state, isA<ProfileGateUnauthenticated>());
    expect(context.profiles.readCalls, 0);
  });

  test(
    'notificações repetidas do Authentication não reiniciam o portão',
    () async {
      final FakeAuthRepository auth = _verifiedAuth()
        ..emitUserDuringReload = true;
      final _GateContext context = _context(auth);
      addTearDown(context.dispose);

      final ProfileGateState state = await _terminalState(context.container);
      auth.emit(auth.currentUser);
      auth.emit(auth.currentUser);
      await Future<void>.delayed(Duration.zero);

      expect(state, isA<ProfileGateMissing>());
      expect(auth.reloadCalls, 1);
      expect(auth.refreshIdentityCalls, 1);
      expect(context.profiles.readCalls, 1);
    },
  );

  test('chamadas concorrentes de retry não iniciam nova leitura', () async {
    final Completer<void> barrier = Completer<void>();
    final FakeUserProfileRepository profiles = FakeUserProfileRepository()
      ..readBarrier = barrier;
    final _GateContext context = _context(
      _verifiedAuth(),
      profiles: profiles,
      timeout: const Duration(seconds: 1),
    );
    addTearDown(context.dispose);

    unawaited(context.container.read(profileGateControllerProvider.future));
    await _waitUntil(() => profiles.readCalls == 1);
    await context.container
        .read(profileGateControllerProvider.notifier)
        .retry();
    await context.container
        .read(profileGateControllerProvider.notifier)
        .retry();
    expect(profiles.readCalls, 1);

    barrier.complete();
    final ProfileGateState state = await _terminalState(context.container);
    expect(state, isA<ProfileGateMissing>());
  });

  test('retry após timeout conclui e ignora callback antigo', () async {
    final Completer<void> oldBarrier = Completer<void>();
    final FakeUserProfileRepository profiles = FakeUserProfileRepository()
      ..readBarrier = oldBarrier;
    final _GateContext context = _context(_verifiedAuth(), profiles: profiles);
    addTearDown(context.dispose);

    final ProfileGateState first = await _terminalState(context.container);
    expect(first, isA<ProfileGateFailure>());

    profiles
      ..readBarrier = null
      ..profile = createTestProfile(ownerId: 'owner');
    await context.container
        .read(profileGateControllerProvider.notifier)
        .retry();
    oldBarrier.complete();
    await Future<void>.delayed(Duration.zero);

    expect(
      context.container.read(profileGateControllerProvider).value,
      isA<ProfileGateValid>(),
    );
    expect(profiles.readCalls, 2);
  });

  test(
    'logout durante leitura invalida a operação e retorna ao login',
    () async {
      final Completer<void> barrier = Completer<void>();
      final FakeAuthRepository auth = _verifiedAuth();
      final FakeUserProfileRepository profiles = FakeUserProfileRepository()
        ..readBarrier = barrier;
      final _GateContext context = _context(
        auth,
        profiles: profiles,
        timeout: const Duration(seconds: 1),
      );
      addTearDown(context.dispose);

      unawaited(context.container.read(profileGateControllerProvider.future));
      await _waitUntil(() => profiles.readCalls == 1);
      auth.emit(null);
      final ProfileGateState loggedOut = await _terminalState(
        context.container,
      );
      expect(loggedOut, isA<ProfileGateUnauthenticated>());

      barrier.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        context.container.read(profileGateControllerProvider).value,
        isA<ProfileGateUnauthenticated>(),
      );
    },
  );
}

final class _GateContext {
  const _GateContext({
    required this.auth,
    required this.profiles,
    required this.container,
    required this.keepAlive,
  });

  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;
  final ProviderContainer container;
  final ProviderSubscription<AsyncValue<ProfileGateState>> keepAlive;

  void dispose() {
    keepAlive.close();
    container.dispose();
    unawaited(auth.close());
  }
}

FakeAuthRepository _verifiedAuth() {
  return FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
}

_GateContext _context(
  FakeAuthRepository auth, {
  FakeUserProfileRepository? profiles,
  Duration timeout = const Duration(milliseconds: 50),
}) {
  final FakeUserProfileRepository profileRepository =
      profiles ?? FakeUserProfileRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(profileRepository),
      profileGateTimeoutPolicyProvider.overrideWithValue(
        ProfileGateTimeoutPolicy(
          refreshUser: timeout,
          refreshToken: timeout,
          readProfile: timeout,
        ),
      ),
    ],
  );
  final ProviderSubscription<AsyncValue<ProfileGateState>> keepAlive = container
      .listen<AsyncValue<ProfileGateState>>(
        profileGateControllerProvider,
        (previous, next) {},
      );
  return _GateContext(
    auth: auth,
    profiles: profileRepository,
    container: container,
    keepAlive: keepAlive,
  );
}

Future<ProfileGateState> _terminalState(ProviderContainer container) async {
  final Completer<ProfileGateState> completer = Completer<ProfileGateState>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> subscription =
      container.listen<AsyncValue<ProfileGateState>>(
        profileGateControllerProvider,
        (previous, next) {
          final ProfileGateState? value = next.value;
          if (value != null && value.isTerminal && !completer.isCompleted) {
            completer.complete(value);
          }
        },
        fireImmediately: true,
      );
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 2)) {
      throw TimeoutException('Condição de teste não foi alcançada.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
