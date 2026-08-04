import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/providers/financial_commitment_providers.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/positive_money_input_field.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_category_repository.dart';
import '../../../support/fake_financial_commitment_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_master_access_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_category_fixtures.dart';
import '../../../support/financial_commitment_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('home oferece acessos equivalentes para pagar e receber', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _reveal(tester, 'Contas a pagar');
    expect(find.text('Contas a pagar'), findsOneWidget);
    expect(find.text('Contas a receber'), findsOneWidget);
  });

  testWidgets('ações rápidas preselecionam o tipo e Voltar retorna à home', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);

    await _reveal(tester, 'Nova receita');
    await tester.tap(find.text('Nova receita'));
    await tester.pumpAndSettle();
    expect(find.text('Novo lançamento'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<FinancialTransactionKind>>(
            find.byType(SegmentedButton<FinancialTransactionKind>),
          )
          .selected,
      <FinancialTransactionKind>{FinancialTransactionKind.income},
    );

    await tester.tap(find.byType(SafeBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Pessoa!'), findsOneWidget);

    await _reveal(tester, 'Nova despesa');
    await tester.tap(find.text('Nova despesa'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<FinancialTransactionKind>>(
            find.byType(SegmentedButton<FinancialTransactionKind>),
          )
          .selected,
      <FinancialTransactionKind>{FinancialTransactionKind.expense},
    );
  });

  testWidgets('listas vazias explicam que pendências não alteram saldo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.payables);
    expect(
      find.text('Você ainda não cadastrou contas a pagar.'),
      findsOneWidget,
    );
    expect(
      find.text('Compromissos pendentes não alteram o saldo real.'),
      findsOneWidget,
    );
  });

  testWidgets('falha de leitura oferece retry e recupera a lista', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    harness.commitments.readFailure = const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.unavailable,
      safeMessage: 'Sem conexão com o servidor.',
      code: 'test_unavailable',
    );
    await harness.container.read(payablesControllerProvider.notifier).refresh();
    await _go(tester, AppRoutes.payables);
    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    harness.commitments.readFailure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Você ainda não cadastrou contas a pagar.'),
      findsOneWidget,
    );
  });

  testWidgets('filtro visual separa cancelados das pendências', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[
        createTestPayable(id: 'pending', description: 'Pendente visível'),
        createTestPayable(
          id: 'cancelled',
          description: 'Cancelado visível',
          status: PayableStatus.cancelled,
        ),
      ],
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.payables);
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelados').last);
    await tester.pumpAndSettle();
    expect(find.text('Cancelado visível'), findsOneWidget);
    expect(find.text('Pendente visível'), findsNothing);
  });

  testWidgets('criação de conta a pagar usa categoria de despesa', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.newPayable);
    await tester.enterText(_field('Descrição'), 'Aluguel do mês');
    await tester.tap(_dropdown('Categoria'));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsNothing);
    await tester.tap(find.text('Moradia').last);
    await tester.enterText(
      find.descendant(
        of: find.byType(PositiveMoneyInputField),
        matching: find.byType(TextFormField),
      ),
      '1500,00',
    );
    await _reveal(tester, 'Salvar compromisso');
    await tester.tap(find.text('Salvar compromisso'));
    await tester.pumpAndSettle();
    expect(harness.commitments.payables, hasLength(1));
    expect(harness.commitments.payables.single.amountCents, 150000);
    expect(find.text('Detalhes do compromisso'), findsOneWidget);
  });

  testWidgets('criação de conta a receber usa categoria de receita', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.newReceivable);
    await tester.enterText(_field('Descrição'), 'Consultoria');
    await tester.tap(_dropdown('Categoria'));
    await tester.pumpAndSettle();
    expect(find.text('Moradia'), findsNothing);
    await tester.tap(find.text('Salário').last);
    await tester.enterText(
      find.descendant(
        of: find.byType(PositiveMoneyInputField),
        matching: find.byType(TextFormField),
      ),
      '900,00',
    );
    await _reveal(tester, 'Salvar compromisso');
    await tester.tap(find.text('Salvar compromisso'));
    await tester.pumpAndSettle();
    expect(harness.commitments.receivables, hasLength(1));
    expect(
      harness.commitments.receivables.single.categoryId,
      'income-category',
    );
  });

  testWidgets('atraso é derivado e hoje permanece pendente', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[
        createTestPayable(
          id: 'late',
          description: 'Vencida ontem',
          dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 14),
        ),
        createTestPayable(
          id: 'today',
          description: 'Vence hoje',
          dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 15),
        ),
      ],
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.payables);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Vencida ontem'),
          matching: find.byType(Card),
        ),
        matching: find.text('Atrasado'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Vence hoje'),
          matching: find.byType(Card),
        ),
        matching: find.text('Pendente'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('edição direta é bloqueada para estado final', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[createTestPayable(status: PayableStatus.cancelled)],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.editCommitment(FinancialCommitmentKind.payable, 'payable-1'),
    );
    expect(
      find.text('Somente compromissos pendentes podem ser editados.'),
      findsOneWidget,
    );
    expect(find.text('Salvar alterações'), findsNothing);
  });

  testWidgets('edição de pendência salva somente após confirmação', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.editCommitment(
        FinancialCommitmentKind.receivable,
        'receivable-1',
      ),
    );
    await tester.enterText(_field('Descrição'), 'Consultoria revisada');
    final Finder save = find.widgetWithText(FilledButton, 'Salvar alterações');
    await Scrollable.ensureVisible(
      tester.element(save),
      alignment: 0.7,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tapAt(
      Offset(
        tester.getCenter(save).dx,
        tester.getTopLeft(save).dy + AppSpacing.xs,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.commitments.receivables.single.description,
      'Consultoria revisada',
    );
    expect(find.text('Detalhes do compromisso'), findsOneWidget);
  });

  testWidgets(
    'confirmação separa vencimento de movimentação e atualiza saldo',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpHarness(
        tester,
        payables: <Payable>[createTestPayable()],
      );
      addTearDown(harness.dispose);
      await _go(
        tester,
        AppRoutes.commitmentDetails(
          FinancialCommitmentKind.payable,
          'payable-1',
        ),
      );
      await tester.tap(find.text('Confirmar pagamento'));
      await tester.pumpAndSettle();
      expect(find.text('Vencimento previsto: 10/08/2026'), findsOneWidget);
      expect(
        find.textContaining('quando o dinheiro realmente saiu ou entrou'),
        findsOneWidget,
      );
      await tester.tap(find.text('Data da movimentação: 15/08/2026'));
      await tester.pumpAndSettle();
      final CalendarDatePicker picker = tester.widget(
        find.byType(CalendarDatePicker),
      );
      expect(picker.lastDate, DateTime(2026, 8, 15));
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Pagar'));
      await tester.pumpAndSettle();
      expect(harness.commitments.linkedTransactions, hasLength(1));
      expect(find.text('Pago'), findsOneWidget);
      expect(find.text('Data da movimentação real'), findsOneWidget);
    },
  );

  testWidgets('liquidação bloqueia toque repetido enquanto aguarda servidor', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(
        FinancialCommitmentKind.receivable,
        'receivable-1',
      ),
    );
    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();
    final Completer<void> barrier = Completer<void>();
    harness.commitments.mutationBarrier = barrier;
    await tester.tap(find.widgetWithText(FilledButton, 'Receber'));
    await tester.pump();
    final FilledButton button = tester.widget(
      find.widgetWithText(FilledButton, 'Receber'),
    );
    expect(button.onPressed, isNull);
    expect(harness.commitments.settleCalls, 1);
    barrier.complete();
    await tester.pumpAndSettle();
    expect(harness.commitments.settleCalls, 1);
  });

  testWidgets('cancelamento preserva histórico e não cria lançamento', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[createTestPayable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(FinancialCommitmentKind.payable, 'payable-1'),
    );
    await tester.tap(find.byTooltip('Cancelar compromisso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('continuará no histórico'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pendência'));
    await tester.pumpAndSettle();
    expect(harness.commitments.payables.single.isCancelled, isTrue);
    expect(harness.commitments.linkedTransactions, isEmpty);
    expect(find.byTooltip('Cancelar compromisso'), findsNothing);
  });

  testWidgets('anulação explica impacto e invalida lançamento vinculado', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(
        FinancialCommitmentKind.receivable,
        'receivable-1',
      ),
    );
    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Receber'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ver lançamento vinculado'), findsOneWidget);
    await tester.tap(find.byTooltip('Anular liquidação'));
    await tester.pumpAndSettle();
    expect(find.textContaining('não restaura a pendência'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Anular liquidação'));
    await tester.pumpAndSettle();
    expect(harness.commitments.receivables.single.isVoided, isTrue);
    expect(harness.commitments.linkedTransactions.single.isVoided, isTrue);
    expect(find.text('Anulado'), findsOneWidget);
  });

  testWidgets('lançamento vinculado bloqueia edição e cancelamento isolados', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[createTestPayable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(FinancialCommitmentKind.payable, 'payable-1'),
    );
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pagar'));
    await tester.pumpAndSettle();
    final linked = harness.commitments.linkedTransactions.single;
    harness.transactions.transactions.add(linked);
    await _go(tester, AppRoutes.transactionDetails(linked.id));
    expect(find.byTooltip('Editar lançamento'), findsNothing);
    expect(find.byTooltip('Cancelar lançamento'), findsNothing);
    expect(find.text('Conta a pagar vinculada'), findsOneWidget);
    await _reveal(tester, 'Abrir compromisso de origem');
    expect(find.text('Abrir compromisso de origem'), findsOneWidget);

    await _go(tester, AppRoutes.editTransaction(linked.id));
    expect(
      find.textContaining('não pode ser editado isoladamente'),
      findsOneWidget,
    );
    expect(find.text('Salvar alterações'), findsNothing);
  });

  testWidgets('ausência de referências oferece próximo passo seguro', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      accounts: <FinancialAccount>[],
      categories: <FinancialCategory>[],
      payables: <Payable>[createTestPayable()],
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.newPayable);
    expect(
      find.textContaining('Cadastre uma categoria despesa ativa'),
      findsOneWidget,
    );
    expect(find.text('Cadastrar categoria'), findsOneWidget);
    await _go(
      tester,
      AppRoutes.commitmentDetails(FinancialCommitmentKind.payable, 'payable-1'),
    );
    await tester.tap(find.text('Confirmar pagamento'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não há conta ativa disponível'),
      findsOneWidget,
    );
    final FilledButton pay = tester.widget(
      find.widgetWithText(FilledButton, 'Pagar'),
    );
    expect(pay.onPressed, isNull);
  });

  testWidgets('rota direta e voltar seguro retornam à lista correta', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(
        FinancialCommitmentKind.receivable,
        'receivable-1',
      ),
    );
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Contas a receber'), findsOneWidget);
  });

  testWidgets('tela pequena, fonte ampliada e tema escuro preservam ações', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final _Harness harness = await _pumpHarness(
      tester,
      payables: <Payable>[createTestPayable()],
    );
    addTearDown(harness.dispose);
    await _go(
      tester,
      AppRoutes.commitmentDetails(FinancialCommitmentKind.payable, 'payable-1'),
    );
    expect(find.text('Confirmar pagamento'), findsOneWidget);
    final Finder edit = find.byTooltip('Editar compromisso');
    final Finder cancel = find.byTooltip('Cancelar compromisso');
    expect(edit, findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(tester.getCenter(edit).dy, tester.getCenter(cancel).dy);
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cartão expõe descrição, valor, vencimento e estado à semântica',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final _Harness harness = await _pumpHarness(
        tester,
        payables: <Payable>[createTestPayable()],
      );
      addTearDown(harness.dispose);
      await _go(tester, AppRoutes.payables);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Conta de energia, R\$ 125,00, vencimento 10/08/2026, Atrasado',
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
}

final class _Harness {
  const _Harness({
    required this.auth,
    required this.commitments,
    required this.transactions,
    required this.container,
  });

  final FakeAuthRepository auth;
  final FakeFinancialCommitmentRepository commitments;
  final FakeFinancialTransactionRepository transactions;
  final ProviderContainer container;

  void dispose() => unawaited(auth.close());
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  List<Payable>? payables,
  List<Receivable>? receivables,
  List<FinancialAccount>? accounts,
  List<FinancialCategory>? categories,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialCommitmentRepository commitments =
      FakeFinancialCommitmentRepository(
        initialPayables: payables,
        initialReceivables: receivables,
      );
  final FakeFinancialTransactionRepository transactions =
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
        masterAccessRepositoryProvider.overrideWithValue(
          FakeMasterAccessRepository(),
        ),
        userProfileRepositoryProvider.overrideWithValue(
          FakeUserProfileRepository(
            initialProfile: createTestProfile(ownerId: 'owner'),
          ),
        ),
        financialAccountRepositoryProvider.overrideWithValue(
          FakeFinancialAccountRepository(
            initialAccounts:
                accounts ?? <FinancialAccount>[createTestAccount()],
          ),
        ),
        financialCategoryRepositoryProvider.overrideWithValue(
          FakeFinancialCategoryRepository(
            initialCategories:
                categories ??
                <FinancialCategory>[
                  createTestCategory(id: 'income-category', name: 'Salário'),
                  createTestCategory(
                    id: 'expense-category',
                    name: 'Moradia',
                    kind: FinancialCategoryKind.expense,
                    icon: FinancialCategoryIcon.home,
                    color: FinancialCategoryColor.blue,
                  ),
                ],
          ),
        ),
        financialTransactionRepositoryProvider.overrideWithValue(transactions),
        financialCommitmentRepositoryProvider.overrideWithValue(commitments),
        financialClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 8, 15, 15),
        ),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  return _Harness(
    auth: auth,
    commitments: commitments,
    transactions: transactions,
    container: ProviderScope.containerOf(context),
  );
}

Future<void> _go(WidgetTester tester, String location) async {
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String text) async {
  final Finder target = find.text(text);
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target.last);
  } else {
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.pumpAndSettle();
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Finder _dropdown(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);
