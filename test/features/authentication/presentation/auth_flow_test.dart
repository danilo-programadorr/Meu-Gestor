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

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('falha de inicialização mostra mensagem segura', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);

    await _pumpApp(
      tester,
      repository: repository,
      startup: const FirebaseStartupFailure(),
    );

    expect(find.text('Serviço indisponível'), findsOneWidget);
    expect(
      find.text(
        'Não foi possível iniciar o acesso seguro. Feche o aplicativo e tente novamente.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('production bloqueia configuração development', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);

    await _pumpApp(
      tester,
      repository: repository,
      environment: AppEnvironment.production,
      startup: const FirebaseStartupProductionBlocked(),
    );

    expect(
      find.text('O ambiente de produção ainda não foi configurado.'),
      findsOneWidget,
    );
  });

  testWidgets('usuário não verificado só acessa tela de confirmação', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository(
      initialUser: const AuthUser(
        id: 'user',
        email: 'pessoa@exemplo.com',
        emailVerified: false,
      ),
    );
    addTearDown(repository.close);

    await _pumpApp(tester, repository: repository);

    expect(find.text('Confirme seu email'), findsOneWidget);
    expect(find.textContaining('p***@e***.com'), findsOneWidget);
    expect(find.text('Reenviar email de confirmação'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);
  });

  testWidgets(
    'usuário verificado acessa área autenticada com entrada para contas',
    (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository(
        initialUser: const AuthUser(
          id: 'user',
          email: 'pessoa@exemplo.com',
          emailVerified: true,
        ),
      );
      addTearDown(repository.close);

      await _pumpApp(tester, repository: repository);

      expect(find.text('Área autenticada'), findsNothing);
      expect(find.text('Olá, Pessoa!'), findsOneWidget);
      expect(find.text('Meu Gestor Financeiro'), findsOneWidget);
    },
  );

  testWidgets('navega entre login, cadastro e redefinição', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);
    await _pumpApp(tester, repository: repository);

    await _tapVisible(tester, find.text('Cadastre-se'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta'), findsWidgets);

    await _tapVisible(tester, find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);

    await _tapVisible(tester, find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();
    expect(find.text('Redefinir senha'), findsOneWidget);
    expect(find.text('Voltar para o login'), findsOneWidget);
  });

  testWidgets('login valida email vazio, formato e senha vazia', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);
    await _pumpApp(tester, repository: repository);

    await _tapVisible(tester, find.text('Entrar agora'));
    await tester.pump();
    expect(find.text('Informe seu email.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'email-invalido');
    await _tapVisible(tester, find.text('Entrar agora'));
    await tester.pump();
    expect(find.text('Informe um email válido.'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });

  testWidgets('cadastro exige senha forte, confirmação e consentimentos', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);
    await _pumpApp(tester, repository: repository);
    await _tapVisible(tester, find.text('Cadastre-se'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Pessoa Teste');
    await tester.enterText(fields.at(1), 'pessoa@exemplo.com');
    await tester.enterText(fields.at(2), 'fraca');
    await tester.enterText(fields.at(3), 'diferente');
    await _tapVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Criar conta'),
    );
    await tester.pump();

    expect(find.textContaining('Use 8 ou mais caracteres'), findsWidgets);
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(find.textContaining('Aceite os Termos de Uso'), findsOneWidget);
    expect(repository.createAccountCalls, 0);
  });

  testWidgets('recuperação apresenta resposta genérica', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);
    await _pumpApp(tester, repository: repository);
    await _tapVisible(tester, find.text('Esqueceu a senha?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'pessoa@exemplo.com');
    await _tapVisible(tester, find.text('Enviar link de redefinição'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Se houver uma conta associada a este email, enviaremos as instruções de redefinição.',
      ),
      findsOneWidget,
    );
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
    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);

    await _pumpApp(tester, repository: repository);
    await _tapVisible(tester, find.byType(TextFormField).first);
    await tester.pump();

    final Object? layoutException = tester.takeException();

    expect(
      layoutException,
      isNull,
      reason: layoutException is FlutterError
          ? layoutException.toStringDeep()
          : null,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('ações principais possuem semântica e não há botão Apple', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    final FakeAuthRepository repository = FakeAuthRepository();
    addTearDown(repository.close);

    await _pumpApp(tester, repository: repository);

    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.textContaining('Apple'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Pessoas organizando informações financeiras em um tablet',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Entrar agora'), findsAtLeastNWidgets(1));
    semantics.dispose();
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository repository,
  FirebaseStartupState startup = const FirebaseStartupAvailable(),
  AppEnvironment environment = AppEnvironment.development,
}) async {
  final AuthUser? user = repository.currentUser;
  final FakeUserProfileRepository profileRepository = FakeUserProfileRepository(
    initialProfile: user?.emailVerified == true
        ? createTestProfile(ownerId: user!.id)
        : null,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        firebaseStartupProvider.overrideWithValue(startup),
        authRepositoryProvider.overrideWithValue(repository),
        masterAccessSubjectProvider.overrideWithValue(null),
        userProfileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
}
