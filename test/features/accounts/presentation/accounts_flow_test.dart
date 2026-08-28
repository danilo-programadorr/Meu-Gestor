import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_card.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('home remove a seção visual de contas e preserva o menu', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpApp(tester);
    addTearDown(context.dispose);

    expect(
      find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
      findsOneWidget,
    );
    expect(find.text('Contas e carteiras'), findsNothing);
    expect(find.text('Ver contas'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dashboard-accounts-carousel')),
      findsNothing,
    );
    expect(find.text('Área autenticada'), findsNothing);
  });

  testWidgets('menu navega para contas e Voltar retorna ao dashboard', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpApp(tester);
    addTearDown(context.dispose);

    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Organização'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Contas e carteiras'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Contas e carteiras'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
      findsOneWidget,
    );
  });

  testWidgets('rota de contas permanece bloqueada sem email confirmado', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpApp(tester, emailVerified: false);
    addTearDown(context.dispose);

    expect(find.text('Confirme seu email'), findsOneWidget);
    final BuildContext pageContext = tester.element(
      find.text('Confirme seu email'),
    );
    GoRouter.of(pageContext).go(AppRoutes.accounts);
    await tester.pumpAndSettle();

    expect(find.text('Confirme seu email'), findsOneWidget);
    expect(find.text('Contas e carteiras'), findsNothing);
    expect(context.accounts.readCalls, 0);
  });

  testWidgets('lista vazia usa orientação aprovada e não inventa dados', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(tester);
    addTearDown(context.dispose);

    expect(
      find.text('Você ainda não cadastrou nenhuma conta.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Adicione sua primeira conta ou carteira para começar a organizar seus saldos.',
      ),
      findsOneWidget,
    );
    expect(find.text(r'R$ 0,00'), findsOneWidget);
    expect(find.text('Adicionar conta'), findsOneWidget);
    expect(find.byTooltip('Adicionar conta'), findsOneWidget);
  });

  testWidgets('lista exibe total, tipos e exclusão do total', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[
        createTestAccount(openingBalanceCents: 100000),
        createTestAccount(
          id: 'account-2',
          name: 'Dinheiro da carteira',
          type: FinancialAccountType.cash,
          openingBalanceCents: 2500,
          includeInTotal: false,
        ),
      ],
    );
    addTearDown(context.dispose);

    expect(find.text(r'R$ 1.000,00'), findsNWidgets(2));
    expect(find.text('2 contas ativas'), findsOneWidget);
    expect(find.text('Conta corrente'), findsOneWidget);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(find.text('Não participa do total geral'), findsOneWidget);
  });

  testWidgets('lista ativa alinha editar e arquivar com confirmação segura', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);

    final Finder edit = find.byTooltip('Editar conta');
    final Finder archive = find.byTooltip('Arquivar conta');
    expect(edit, findsOneWidget);
    expect(archive, findsOneWidget);
    expect(find.bySemanticsLabel('Editar conta'), findsOneWidget);
    expect(find.bySemanticsLabel('Arquivar conta'), findsOneWidget);
    expect(tester.getSize(edit).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(archive).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(archive).height, greaterThanOrEqualTo(44));
    expect(tester.getCenter(edit).dy, tester.getCenter(archive).dy);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(archive);
    await tester.pumpAndSettle();
    expect(find.text('Arquivar esta conta?'), findsOneWidget);
    expect(find.textContaining('Nenhum dado será apagado'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(context.accounts.archiveCalls, 0);
    semantics.dispose();
  });

  testWidgets('cria uma conta uma única vez e abre detalhes', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(tester);
    addTearDown(context.dispose);

    await tester.tap(find.byTooltip('Adicionar conta'));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Conta   2  ');
    await tester.enterText(fields.at(1), '-1.234,56');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pumpAndSettle();

    expect(context.accounts.createCalls, 1);
    expect(context.accounts.accounts, hasLength(1));
    expect(context.accounts.accounts.single.name, 'Conta 2');
    expect(context.accounts.accounts.single.openingBalanceCents, -123456);
    expect(find.text('Detalhes da conta'), findsOneWidget);
    expect(find.text(r'-R$ 1.234,56'), findsNWidgets(2));
    expect(find.text('Excluir conta'), findsNothing);
  });

  testWidgets('edita campos autorizados sem expor IDs', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);

    await _openDetails(tester, 'account-1');
    expect(find.text('Detalhes da conta'), findsOneWidget);
    expect(find.text('owner'), findsNothing);
    expect(find.text('account-1'), findsNothing);
    await _scrollUntilVisible(tester, find.text('Editar conta'));
    await tester.tap(find.text('Editar conta').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Conta revisada');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();

    expect(context.accounts.updateCalls, 1);
    expect(context.accounts.accounts.single.name, 'Conta revisada');
    expect(find.text('Conta revisada'), findsOneWidget);
  });

  testWidgets('arquivamento pede confirmação e não apaga', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);

    await _openDetails(tester, 'account-1');
    await _scrollUntilVisible(tester, find.text('Arquivar conta'));
    await tester.tap(find.text('Arquivar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivar esta conta?'), findsOneWidget);
    expect(find.textContaining('Nenhum dado será apagado'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
    await tester.pumpAndSettle();

    expect(context.accounts.archiveCalls, 1);
    expect(context.accounts.accounts, hasLength(1));
    expect(context.accounts.accounts.single.isArchived, isTrue);
    expect(find.text('Contas arquivadas'), findsOneWidget);
  });

  testWidgets('conta arquivada pode ser restaurada', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[createTestAccount(isArchived: true)],
    );
    addTearDown(context.dispose);

    await _scrollUntilVisible(
      tester,
      find.textContaining('Contas arquivadas (1)'),
    );
    await tester.tap(find.textContaining('Contas arquivadas (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Arquivada em'), findsOneWidget);
    final Finder restore = find.byTooltip('Restaurar conta');
    expect(tester.getSize(restore).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(restore).height, greaterThanOrEqualTo(44));
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(context.accounts.accounts.single.isArchived, isFalse);
    expect(context.accounts.accounts.single.archivedAt, isNull);
  });

  testWidgets('tela pequena com fonte ampliada não apresenta overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _WidgetContext context = await _pumpAccounts(
      tester,
      accounts: <FinancialAccount>[createTestAccount()],
    );
    addTearDown(context.dispose);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulário com teclado aberto permanece rolável', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final _WidgetContext context = await _pumpAccounts(tester);
    addTearDown(context.dispose);

    await tester.tap(find.byTooltip('Adicionar conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interface oferece semântica nos temas claro e escuro', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final _WidgetContext context = await _pumpAccounts(tester);
    addTearDown(context.dispose);

    expect(
      find.bySemanticsLabel(RegExp('Total das contas incluídas')),
      findsWidgets,
    );
    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.system);
    semantics.dispose();
  });

  testWidgets('cartão financeiro mantém estado textual nos dois temas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SafeArea(
              child: AccountCard(
                account: createTestAccount(),
                currentBalance: Money.fromCents(-9999999999),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conta principal'), findsOneWidget);
      expect(find.text('Saldo negativo'), findsOneWidget);
      expect(find.text('-R\$ 99.999.999,99'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

final class _WidgetContext {
  const _WidgetContext({required this.auth, required this.accounts});

  final FakeAuthRepository auth;
  final FakeFinancialAccountRepository accounts;

  void dispose() => unawaited(auth.close());
}

Future<_WidgetContext> _pumpApp(
  WidgetTester tester, {
  List<FinancialAccount>? accounts,
  bool emailVerified = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: emailVerified,
    ),
  );
  final FakeUserProfileRepository profiles = FakeUserProfileRepository(
    initialProfile: createTestProfile(ownerId: 'owner'),
  );
  final FakeFinancialAccountRepository accountRepository =
      FakeFinancialAccountRepository(initialAccounts: accounts);
  final FakeFinancialTransactionRepository transactionRepository =
      FakeFinancialTransactionRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
        firebaseStartupProvider.overrideWithValue(
          const FirebaseStartupAvailable(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        masterAccessSubjectProvider.overrideWithValue(null),
        userProfileRepositoryProvider.overrideWithValue(profiles),
        financialAccountRepositoryProvider.overrideWithValue(accountRepository),
        financialTransactionRepositoryProvider.overrideWithValue(
          transactionRepository,
        ),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _WidgetContext(auth: auth, accounts: accountRepository);
}

Future<_WidgetContext> _pumpAccounts(
  WidgetTester tester, {
  List<FinancialAccount>? accounts,
}) async {
  final _WidgetContext context = await _pumpApp(tester, accounts: accounts);
  await tester.tap(
    find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Organização'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Contas e carteiras'),
    ),
  );
  await tester.pumpAndSettle();
  return context;
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _openDetails(WidgetTester tester, String accountId) async {
  final BuildContext context = tester.element(find.byType(AccountCard).first);
  unawaited(
    GoRouter.of(context).push<void>(AppRoutes.accountDetails(accountId)),
  );
  await tester.pumpAndSettle();
}
