import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/pages/owner_area_page.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/widgets/owner_access_badge.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_category_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_master_access_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('31. owner vê Acesso proprietário', (WidgetTester tester) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openProfile(tester);
    expect(find.text('Acesso proprietário'), findsOneWidget);
  });

  testWidgets('32. usuário comum não vê selo nem espaço reservado', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester);
    addTearDown(harness.dispose);
    await _openProfile(tester);
    expect(find.byType(OwnerAccessBadge), findsNothing);
    expect(find.text('Acesso proprietário'), findsNothing);
  });

  testWidgets('33. owner abre /proprietario', (WidgetTester tester) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.byType(OwnerAreaPage), findsOneWidget);
    expect(find.text('Área do proprietário'), findsOneWidget);
  });

  testWidgets('34. usuário comum não acessa /proprietario', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.ownerArea);
    expect(find.byType(OwnerAreaPage), findsNothing);
    expect(find.text('Módulos disponíveis'), findsNothing);
  });

  testWidgets('35. acesso direto sem autorização redireciona com segurança', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.ownerArea);
    expect(find.byType(OwnerAreaPage), findsNothing);
    expect(find.text('Módulos disponíveis'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('36. loading não mostra conteúdo administrativo', (
    WidgetTester tester,
  ) async {
    final Completer<void> barrier = Completer<void>();
    final _OwnerHarness harness = await _pumpOwnerApp(
      tester,
      owner: true,
      barrier: barrier,
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.ownerArea, settle: false);
    await tester.pump();
    expect(find.text('Módulos disponíveis'), findsNothing);
    expect(harness.state.status, MasterAccessStatus.loading);
    barrier.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('37. revogação remove acesso', (WidgetTester tester) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openProfile(tester);
    expect(find.text('Acesso proprietário'), findsOneWidget);
    harness.master.result = FakeMasterAccessRepository.revokedResult();
    await harness.controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Acesso proprietário'), findsNothing);
    expect(harness.state.status, MasterAccessStatus.revoked);
  });

  testWidgets('38. Atualizar acesso revalida no servidor', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    final int before = harness.master.readCalls;
    await tester.ensureVisible(find.text('Atualizar acesso'));
    await tester.tap(find.text('Atualizar acesso'));
    await tester.pumpAndSettle();
    expect(harness.master.readCalls, before + 1);
    expect(find.text('Área do proprietário'), findsOneWidget);
  });

  testWidgets('39. sem internet não concede acesso', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(
      tester,
      failure: const MasterAccessFailure(
        kind: MasterAccessFailureKind.unavailable,
        safeMessage: 'Temporariamente indisponível.',
        code: 'unavailable',
      ),
    );
    addTearDown(harness.dispose);
    expect(harness.state.isActiveOwner, isFalse);
    await _go(tester, AppRoutes.ownerArea);
    expect(find.byType(OwnerAreaPage), findsNothing);
  });

  testWidgets(
    '40. módulos normais continuam acessíveis em erro administrativo',
    (WidgetTester tester) async {
      final _OwnerHarness harness = await _pumpOwnerApp(
        tester,
        failure: const MasterAccessFailure(
          kind: MasterAccessFailureKind.permissionDenied,
          safeMessage: 'Acesso não confirmado.',
          code: 'permission-denied',
        ),
      );
      addTearDown(harness.dispose);
      await _go(tester, AppRoutes.transactions);
      expect(find.text('Novo lançamento'), findsWidgets);
    },
  );

  testWidgets('41. área owner funciona no tema claro', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.text('Owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('42. área owner funciona no tema escuro', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.text('Owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('43. área owner funciona em tela pequena', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    await tester.ensureVisible(find.text('Atualizar acesso'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('44. área owner funciona com fonte ampliada', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    await tester.ensureVisible(find.text('Atualizar acesso'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('45. selo e área possuem semântica', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openProfile(tester);
    expect(
      find.bySemanticsLabel('Acesso proprietário. Abrir Área do proprietário'),
      findsOneWidget,
    );
    await _openOwnerAreaFromProfile(tester);
    expect(
      find.bySemanticsLabel('Papel Owner confirmado pelo servidor'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('46. área owner não apresenta overflow', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('47. botão físico Voltar retorna à tela anterior', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openProfile(tester);
    await _openOwnerAreaFromProfile(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Área do proprietário'), findsNothing);
  });

  testWidgets('48. nenhum UID é exibido', (WidgetTester tester) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.textContaining('test-user-a'), findsNothing);
  });

  testWidgets('49. nenhum e-mail é exibido na área owner', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.textContaining('@example.invalid'), findsNothing);
  });

  testWidgets('50. nenhum dado de outro usuário é exibido', (
    WidgetTester tester,
  ) async {
    final _OwnerHarness harness = await _pumpOwnerApp(tester, owner: true);
    addTearDown(harness.dispose);
    await _openOwnerArea(tester);
    expect(find.text('Lista de usuários'), findsNothing);
    expect(find.text('Pesquisar usuários'), findsNothing);
    expect(find.text('Saldo de terceiros'), findsNothing);
  });
}

final class _OwnerHarness {
  const _OwnerHarness({
    required this.auth,
    required this.master,
    required this.container,
  });

  final FakeAuthRepository auth;
  final FakeMasterAccessRepository master;
  final ProviderContainer container;

  MasterAccessController get controller =>
      container.read(masterAccessControllerProvider.notifier);
  MasterAccessState get state => container.read(masterAccessControllerProvider);

  void dispose() => unawaited(auth.close());
}

Future<_OwnerHarness> _pumpOwnerApp(
  WidgetTester tester, {
  bool owner = false,
  MasterAccessFailure? failure,
  Completer<void>? barrier,
}) async {
  const String userId = 'test-user-a';
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: userId,
      displayName: 'Pessoa Teste',
      email: 'test-owner@example.invalid',
      emailVerified: true,
    ),
  );
  final FakeMasterAccessRepository master =
      FakeMasterAccessRepository(
          result: owner
              ? FakeMasterAccessRepository.activeOwnerResult()
              : FakeMasterAccessRepository.regularUserResult(),
        )
        ..nextFailure = failure
        ..barrier = barrier;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
        firebaseStartupProvider.overrideWithValue(
          const FirebaseStartupAvailable(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        userProfileRepositoryProvider.overrideWithValue(
          FakeUserProfileRepository(
            initialProfile: createTestProfile(ownerId: userId),
          ),
        ),
        financialAccountRepositoryProvider.overrideWithValue(
          FakeFinancialAccountRepository(),
        ),
        financialCategoryRepositoryProvider.overrideWithValue(
          FakeFinancialCategoryRepository(),
        ),
        financialTransactionRepositoryProvider.overrideWithValue(
          FakeFinancialTransactionRepository(),
        ),
        masterAccessRepositoryProvider.overrideWithValue(master),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  return _OwnerHarness(
    auth: auth,
    master: master,
    container: ProviderScope.containerOf(context),
  );
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
  );
  await tester.pumpAndSettle();
  final Finder profile = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text('Perfil'),
  );
  await tester.ensureVisible(profile);
  await tester.pumpAndSettle();
  await tester.tap(profile);
  await tester.pumpAndSettle();
}

Future<void> _openOwnerArea(WidgetTester tester) async {
  await _openProfile(tester);
  await _openOwnerAreaFromProfile(tester);
}

Future<void> _openOwnerAreaFromProfile(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Acesso proprietário'));
  await tester.tap(find.text('Acesso proprietário'));
  await tester.pumpAndSettle();
}

Future<void> _go(
  WidgetTester tester,
  String location, {
  bool settle = true,
}) async {
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
  if (settle) {
    await tester.pumpAndSettle();
  }
}
