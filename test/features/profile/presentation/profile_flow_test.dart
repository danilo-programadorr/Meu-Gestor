import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('usuário verificado sem perfil vê configuração inicial', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    expect(find.text('Complete seu perfil'), findsOneWidget);
    expect(find.text('pt-BR'), findsOneWidget);
    expect(find.text('BRL'), findsOneWidget);
    expect(find.text('America/Sao_Paulo'), findsOneWidget);
    expect(find.textContaining('IA ainda não está ativa'), findsOneWidget);
    expect(
      find.textContaining('Analytics ainda não está ativo'),
      findsOneWidget,
    );
    expect(
      tester.widgetList<Switch>(find.byType(Switch)).map((item) => item.value),
      everyElement(isFalse),
    );
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((item) => item.value),
      everyElement(isFalse),
    );
  });

  testWidgets('configuração exige os dois aceites obrigatórios', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    expect(find.textContaining('Aceite os Termos de Uso'), findsOneWidget);
    expect(context.profiles.createCalls, 0);
  });

  testWidgets('configuração cria perfil e libera área autenticada', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    final Finder checkboxes = find.byType(Checkbox);
    await _tapVisible(tester, checkboxes.at(0));
    await tester.pump();
    await _tapVisible(tester, checkboxes.at(1));
    await tester.pump();
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(context.profiles.createCalls, 1);
    expect(find.text('Área autenticada'), findsOneWidget);
    expect(context.profiles.profile?.aiConsentEnabled, isFalse);
    expect(context.profiles.profile?.analyticsConsentEnabled, isFalse);
  });

  testWidgets('perfil e consentimentos exibem apenas dados autorizados', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(
      tester,
      profile: createTestProfile(ownerId: 'owner'),
    );
    addTearDown(context.dispose);

    await _tapVisible(tester, find.text('Abrir perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Pessoa Teste'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('owner'), findsNothing);

    await _tapVisible(tester, find.text('Privacidade e consentimentos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('terms-dev-1.0.0'), findsOneWidget);
    expect(find.textContaining('privacy-dev-1.0.0'), findsOneWidget);
    expect(find.text('Salvar preferências'), findsOneWidget);
  });

  testWidgets('versão jurídica antiga bloqueia home e exige novo aceite', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(
      tester,
      profile: createTestProfile(
        ownerId: 'owner',
        privacyVersion: 'privacy-dev-0.9.0',
      ),
    );
    addTearDown(context.dispose);

    expect(find.text('Revise as versões atuais'), findsOneWidget);
    expect(find.text('Área autenticada'), findsNothing);
    expect(find.text('Sair da conta'), findsOneWidget);
  });

  testWidgets('token pendente mostra tentativa segura sem acessar perfil', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = _verifiedAuth()..tokenEmailVerified = false;
    final _WidgetContext context = await _pumpProfileApp(tester, auth: auth);
    addTearDown(context.dispose);

    expect(find.text('Confirme seu email'), findsOneWidget);
    expect(find.text('Atualizar confirmação'), findsOneWidget);
    expect(context.profiles.readCalls, 0);
  });

  testWidgets('permissão negada apresenta mensagem sanitizada', (
    WidgetTester tester,
  ) async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository()
      ..nextFailure = const UserProfileFailure(
        kind: UserProfileFailureKind.permissionDenied,
        safeMessage: 'Não foi possível acessar seu perfil com segurança.',
      );
    final _WidgetContext context = await _pumpProfileApp(
      tester,
      profiles: profiles,
    );
    addTearDown(context.dispose);

    expect(
      find.text('Não foi possível acessar seu perfil com segurança.'),
      findsOneWidget,
    );
    expect(find.text('PROFILE_PERMISSION_DENIED'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('redirects repetidos não reiniciam leitura do perfil', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    context.auth.emit(context.auth.currentUser);
    context.auth.emit(context.auth.currentUser);
    await tester.pumpAndSettle();

    expect(find.text('Complete seu perfil'), findsOneWidget);
    expect(context.auth.reloadCalls, 1);
    expect(context.auth.refreshIdentityCalls, 1);
    expect(context.profiles.readCalls, 1);
  });

  testWidgets('tela pequena, teclado e fonte ampliada não geram overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    await tester.ensureVisible(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField));
    await tester.pump();

    final Object? exception = tester.takeException();
    expect(exception, isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('configuração possui semântica no tema claro e escuro', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    expect(
      find.bySemanticsLabel('Configuração segura do perfil'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Continuar e criar perfil'), findsOneWidget);
    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.system);
    semantics.dispose();
  });

  testWidgets('configuração permite logout sem criar perfil', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpProfileApp(tester);
    addTearDown(context.dispose);

    await _tapVisible(tester, find.text('Sair da conta'));
    await tester.pumpAndSettle();

    expect(context.auth.signOutCalls, 1);
    expect(context.profiles.createCalls, 0);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('envio desabilita botão e evita múltiplos toques', (
    WidgetTester tester,
  ) async {
    final FakeUserProfileRepository profiles = FakeUserProfileRepository();
    final Completer<void> barrier = Completer<void>();
    profiles.createBarrier = barrier;
    final _WidgetContext context = await _pumpProfileApp(
      tester,
      profiles: profiles,
    );
    addTearDown(context.dispose);

    final Finder checkboxes = find.byType(Checkbox);
    await _tapVisible(tester, checkboxes.at(0));
    await tester.pump();
    await _tapVisible(tester, checkboxes.at(1));
    await tester.pump();
    final Finder continueButton = find.widgetWithText(
      FilledButton,
      'Continuar',
    );
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pump();

    final FilledButton loadingButton = tester.widget<FilledButton>(
      continueButton,
    );
    expect(loadingButton.onPressed, isNull);
    expect(profiles.createCalls, 1);

    barrier.complete();
    await tester.pumpAndSettle();
    expect(profiles.createCalls, 1);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

final class _WidgetContext {
  const _WidgetContext({required this.auth, required this.profiles});

  final FakeAuthRepository auth;
  final FakeUserProfileRepository profiles;

  void dispose() {
    unawaited(auth.close());
  }
}

Future<_WidgetContext> _pumpProfileApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeUserProfileRepository? profiles,
  UserProfile? profile,
}) async {
  final FakeAuthRepository authRepository = auth ?? _verifiedAuth();
  final FakeUserProfileRepository profileRepository =
      profiles ?? FakeUserProfileRepository(initialProfile: profile);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
        firebaseStartupProvider.overrideWithValue(
          const FirebaseStartupAvailable(),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        masterAccessSubjectProvider.overrideWithValue(null),
        userProfileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _WidgetContext(auth: authRepository, profiles: profileRepository);
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
