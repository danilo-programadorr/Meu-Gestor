import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_filter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_category_fixtures.dart';
import '../../../support/financial_commitment_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('apresenta a hierarquia e os valores financeiros corretos', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);

    expect(find.text('Olá, Hellen!'), findsOneWidget);
    expect(find.text('DEVELOPMENT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-balance-card')),
      findsOneWidget,
    );
    expect(find.text('R\$ 3.000,00'), findsAtLeastNWidgets(1));

    await _reveal(tester, 'Receitas x despesas');
    expect(find.text('R\$ 2.500,00'), findsAtLeastNWidgets(1));
    expect(find.text('R\$ 500,00'), findsAtLeastNWidgets(1));
    expect(find.text('R\$ 2.000,00'), findsAtLeastNWidgets(1));
    expect(
      _semanticsLabel(
        'Gráfico de colunas agrupadas do período Este mês: '
        'receitas R\$ 2.500,00; despesas R\$ 500,00. '
        'As duas colunas usam a mesma escala e linha de base. '
        'Resultado R\$ 2.000,00, positivo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('gráfico agrupado exibe legenda, período e resultado reais', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, tracker: _DashboardTracker());
    await _reveal(tester, 'Receitas x despesas');

    final Finder chart = find.byKey(
      const ValueKey<String>('dashboard-income-expense-chart'),
    );
    expect(chart, findsOneWidget);
    expect(
      find.descendant(
        of: chart,
        matching: find.byKey(
          const ValueKey<String>('dashboard-grouped-column-chart'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chart, matching: find.text('Receitas')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chart, matching: find.text('Despesas')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chart, matching: find.text('Este mês')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chart, matching: find.text('Resultado positivo')),
      findsOneWidget,
    );
  });

  testWidgets('gráfico agrupado preserva privacidade, temas e fonte ampliada', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      await _pumpDashboard(
        tester,
        tracker: _DashboardTracker(),
        theme: theme,
        textScale: 1.8,
      );
      await tester.ensureVisible(find.byTooltip('Ocultar valores'));
      await tester.pump();
      await tester.tap(find.byTooltip('Ocultar valores'));
      await tester.pump();
      await _reveal(tester, 'Receitas x despesas');

      expect(
        find.byKey(const ValueKey<String>('dashboard-grouped-column-chart')),
        findsOneWidget,
      );
      expect(
        _semanticsLabel(
          'Comparação de receitas e despesas com valores ocultos. '
          'Resultado com valor oculto.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('oculta todos os valores sem removê-los da estrutura', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);

    await tester.tap(find.byTooltip('Ocultar valores'));
    await tester.pump();

    expect(find.text('R\$ 3.000,00'), findsNothing);
    expect(find.text('••••••'), findsWidgets);
    expect(
      _semanticsLabel('Saldo atual e resultado do período ocultos.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Exibir valores'), findsOneWidget);
  });

  testWidgets('ações rápidas possuem alvos independentes e acionáveis', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);
    await _reveal(tester, 'Ações rápidas');

    for (final String label in <String>[
      'Nova receita',
      'Nova despesa',
      'Conta a pagar',
      'Conta a receber',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(tracker.newIncome, 1);
    expect(tracker.newExpense, 1);
    expect(tracker.newPayable, 1);
    expect(tracker.newReceivable, 1);
  });

  testWidgets('menu superior abre, fecha e organiza todos os destinos', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);

    expect(find.text('Organizar'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dashboard-menu-button')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Organização'), findsOneWidget);
    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Patrimônio'), findsOneWidget);
    expect(find.text('Conta e aplicativo'), findsOneWidget);
    for (final String item in <String>[
      'Contas e carteiras',
      'Categorias',
      'Lançamentos',
      'Contas a pagar',
      'Contas a receber',
      'Investimentos',
      'Perfil',
      'Aparência',
    ]) {
      expect(_menuItem(item), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Fechar menu'));
    await tester.pumpAndSettle();
    expect(find.text('Organização'), findsNothing);

    for (final String item in <String>[
      'Contas e carteiras',
      'Categorias',
      'Lançamentos',
      'Contas a pagar',
      'Contas a receber',
      'Investimentos',
      'Perfil',
      'Aparência',
    ]) {
      await tester.tap(
        find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
      );
      await tester.pumpAndSettle();
      final Finder destination = _menuItem(item);
      await tester.ensureVisible(destination);
      await tester.pumpAndSettle();
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(find.text('Organização'), findsNothing);
    }

    expect(tracker.accounts, 1);
    expect(tracker.categories, 1);
    expect(tracker.transactions, 1);
    expect(tracker.payables, 1);
    expect(tracker.receivables, 1);
    expect(tracker.investments, 1);
    expect(tracker.profile, 1);
    expect(tracker.appearance, 1);
  });

  testWidgets('menu permanece legível nos temas claro e escuro', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      await _pumpDashboard(tester, tracker: _DashboardTracker(), theme: theme);
      await tester.tap(
        find.byKey(const ValueKey<String>('dashboard-header-menu-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conta e aplicativo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Fechar menu'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('distingue pendências, atrasos e próximos vencimentos', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);
    await _reveal(tester, 'Compromissos pendentes');

    expect(find.text('R\$ 125,00'), findsOneWidget);
    expect(find.text('R\$ 250,00'), findsAtLeastNWidgets(1));
    expect(find.text('1 compromisso'), findsOneWidget);
    expect(find.text('Conta de energia'), findsNothing);
    expect(find.text('Serviço prestado'), findsOneWidget);
    expect(find.text('A receber • 20/08/2026'), findsOneWidget);
    expect(
      find.text('Pendências não alteram seu saldo até a confirmação.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Contas a receber'));
    expect(tracker.receivables, 1);
  });

  testWidgets('mostra lançamentos recentes com contexto e abre detalhes', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);
    await _reveal(tester, 'Lançamentos recentes');

    expect(find.text('Salário mensal'), findsOneWidget);
    expect(find.text('Mercado do mês'), findsOneWidget);
    expect(find.text('Salário • Conta principal'), findsOneWidget);
    expect(find.text('Moradia • Conta principal'), findsOneWidget);

    await tester.tap(find.text('Mercado do mês'));
    expect(tracker.transactionId, 'transaction-expense');
    expect(find.byTooltip('Cancelar lançamento'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('oferece estados vazio, carregando e erro com retry', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(
      tester,
      tracker: tracker,
      workspace: const AsyncLoading<FinancialWorkspace>(),
      payables: const AsyncLoading<FinancialCommitmentsState<Payable>>(),
      receivables: const AsyncLoading<FinancialCommitmentsState<Receivable>>(),
    );
    expect(_semanticsLabel('Carregando dashboard financeiro'), findsOneWidget);

    await _pumpDashboard(
      tester,
      tracker: tracker,
      workspace: AsyncError<FinancialWorkspace>(
        StateError('falha controlada'),
        StackTrace.current,
      ),
    );
    expect(
      find.text('Não foi possível confirmar seu dashboard financeiro.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    expect(tracker.retryWorkspace, 1);

    await _pumpDashboard(
      tester,
      tracker: tracker,
      payables: const AsyncData<FinancialCommitmentsState<Payable>>(
        FinancialCommitmentsState<Payable>(
          commitments: <Payable>[],
          isServerConfirmed: true,
        ),
      ),
      receivables: const AsyncData<FinancialCommitmentsState<Receivable>>(
        FinancialCommitmentsState<Receivable>(
          commitments: <Receivable>[],
          isServerConfirmed: true,
        ),
      ),
      workspace: AsyncData<FinancialWorkspace>(
        _workspace(transactions: const []),
      ),
    );
    await _reveal(tester, 'Tudo organizado por aqui');
    expect(find.text('Seu histórico começa aqui'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permanece responsivo em tela pequena e fonte ampliada', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final ThemeData theme in <ThemeData>[AppTheme.dark, AppTheme.light]) {
      await _pumpDashboard(
        tester,
        tracker: _DashboardTracker(),
        theme: theme,
        textScale: 1.8,
        workspace: AsyncData<FinancialWorkspace>(
          _workspace(
            openingBalanceCents: 9999999999,
            transactions: <FinancialTransaction>[
              createTestTransaction(amountCents: 9999999999),
              createTestTransaction(
                id: 'transaction-expense',
                categoryId: 'expense-category',
                kind: FinancialTransactionKind.expense,
                description: 'Uma descrição financeira extensa para teste',
                amountCents: 9999999999,
              ),
            ],
          ),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'O topo deve caber em 320 px com fonte a 180%.',
      );
      for (final String target in <String>[
        'Ações rápidas',
        'Receitas x despesas',
        'Compromissos pendentes',
        'Lançamentos recentes',
      ]) {
        await _reveal(tester, target);
        expect(
          tester.takeException(),
          isNull,
          reason: 'A seção $target deve permanecer responsiva.',
        );
      }
    }
  });

  testWidgets('expõe semântica e área mínima nos controles do cabeçalho', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, tracker: _DashboardTracker());

    final Finder visibility = _semanticsLabel(
      'Ocultar todos os valores financeiros',
    );
    final Finder menu = _semanticsLabel('Abrir menu de navegação');
    expect(visibility, findsOneWidget);
    expect(menu, findsOneWidget);
    expect(find.byTooltip('Abrir perfil'), findsNothing);
    expect(tester.getSize(visibility).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(visibility).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
    expect(
      tester.getCenter(menu).dx,
      greaterThan(tester.getCenter(visibility).dx),
    );
    expect(tester.getCenter(menu).dy, tester.getCenter(visibility).dy);
  });

  testWidgets('troca tema pelo cabeçalho e expõe somente gráficos reais', (
    WidgetTester tester,
  ) async {
    final _DashboardTracker tracker = _DashboardTracker();
    await _pumpDashboard(tester, tracker: tracker);

    await tester.tap(_semanticsLabel('Ativar tema claro'));
    expect(tracker.toggleTheme, 1);

    await _reveal(tester, 'Despesas por categoria');
    expect(find.text('Moradia'), findsAtLeastNWidgets(1));
    expect(find.text('100%'), findsOneWidget);

    expect(
      find.byKey(const ValueKey<String>('dashboard-accounts-carousel')),
      findsNothing,
    );
    expect(find.text('Adicionar conta'), findsNothing);
  });

  testWidgets('aplica período real pelo bottom sheet sem alterar documentos', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, tracker: _DashboardTracker());

    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-period-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Este ano').last);
    await tester.pumpAndSettle();

    expect(find.text('Este ano'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove resultado duplicado e mantém indicadores equivalentes', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, tracker: _DashboardTracker());

    expect(find.text('Resultado do período'), findsOneWidget);
    expect(find.text('Resultado'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dashboard-receitas-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-despesas-indicator')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-income-expense-chart')),
      findsOneWidget,
    );
  });

  testWidgets('exibe e aplica a ação compacta de limpar filtros', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, tracker: _DashboardTracker());

    expect(
      find.byKey(const ValueKey<String>('dashboard-clear-filters')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-period-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Este ano').last);
    await tester.pumpAndSettle();

    final Finder clear = find.byKey(
      const ValueKey<String>('dashboard-clear-filters'),
    );
    expect(clear, findsOneWidget);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(clear, findsNothing);
    expect(find.text('Este mês'), findsAtLeastNWidgets(1));
  });

  testWidgets('seletor de conta mostra identidade saldo e seleção', (
    WidgetTester tester,
  ) async {
    final List<FinancialAccount> accounts = <FinancialAccount>[
      createTestAccount(),
      createTestAccount(
        id: 'account-2',
        name: 'Carteira diária',
        type: FinancialAccountType.digitalWallet,
        openingBalanceCents: -2500,
      ),
    ];
    await _pumpDashboard(
      tester,
      tracker: _DashboardTracker(),
      workspace: AsyncData<FinancialWorkspace>(
        _workspace(accounts: accounts, transactions: const []),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-account-filter')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conta principal'), findsWidgets);
    expect(find.text('Carteira diária'), findsWidgets);
    expect(find.text('Carteira digital • Negativo'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('-R\$ 25,00'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });

  testWidgets('rosca limita ranking a quatro categorias e Outras', (
    WidgetTester tester,
  ) async {
    final List<FinancialCategory> categories = <FinancialCategory>[
      createTestCategory(),
      for (int index = 1; index <= 6; index += 1)
        createTestCategory(
          id: 'expense-$index',
          name: 'Categoria $index',
          kind: FinancialCategoryKind.expense,
          icon: FinancialCategoryIcon.shopping,
          color: FinancialCategoryColor
              .values[index % FinancialCategoryColor.values.length],
        ),
    ];
    final List<FinancialTransaction> transactions = <FinancialTransaction>[
      for (int index = 1; index <= 6; index += 1)
        createTestTransaction(
          id: 'expense-$index',
          categoryId: 'expense-$index',
          kind: FinancialTransactionKind.expense,
          amountCents: (7 - index) * 10000,
          occurredAt: DateTime.utc(2026, 8, index, 3),
        ),
    ];
    await _pumpDashboard(
      tester,
      tracker: _DashboardTracker(),
      workspace: AsyncData<FinancialWorkspace>(
        _workspace(categories: categories, transactions: transactions),
      ),
    );
    await _reveal(tester, 'Despesas por categoria');

    expect(
      find.byKey(const ValueKey<String>('dashboard-expense-donut')),
      findsOneWidget,
    );
    for (int index = 1; index <= 4; index += 1) {
      expect(find.text('Categoria $index'), findsOneWidget);
    }
    expect(find.text('Categoria 5'), findsNothing);
    expect(find.text('Outras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove a seção de contas e preserva o filtro compacto', (
    WidgetTester tester,
  ) async {
    final List<FinancialAccount> accounts = <FinancialAccount>[
      for (int index = 1; index <= 4; index += 1)
        createTestAccount(
          id: 'account-$index',
          name: 'Conta $index',
          openingBalanceCents: index * 10000,
        ),
    ];
    await _pumpDashboard(
      tester,
      tracker: _DashboardTracker(),
      workspace: AsyncData<FinancialWorkspace>(
        _workspace(accounts: accounts, transactions: const []),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-account-filter')),
      findsOneWidget,
    );
    expect(find.text('Contas e carteiras'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dashboard-accounts-carousel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dashboard-add-account-card')),
      findsNothing,
    );
    expect(find.text('Adicionar conta'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('dashboard-account-filter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conta do dashboard'), findsOneWidget);
    await tester.tap(find.text('Conta 2'));
    await tester.pumpAndSettle();
    expect(find.text('Conta 2'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required _DashboardTracker tracker,
  AsyncValue<FinancialWorkspace>? workspace,
  AsyncValue<FinancialCommitmentsState<Payable>>? payables,
  AsyncValue<FinancialCommitmentsState<Receivable>>? receivables,
  ThemeData? theme,
  double textScale = 1,
}) async {
  final ValueNotifier<bool> visibility = ValueNotifier<bool>(true);
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 15,
  );
  final ValueNotifier<HomeDashboardFilter> filter =
      ValueNotifier<HomeDashboardFilter>(
        HomeDashboardFilter.currentMonth(today),
      );
  addTearDown(visibility.dispose);
  addTearDown(filter.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: visibility,
            builder: (BuildContext context, bool visible, Widget? child) =>
                ValueListenableBuilder<HomeDashboardFilter>(
                  valueListenable: filter,
                  builder:
                      (
                        BuildContext context,
                        HomeDashboardFilter selectedFilter,
                        Widget? child,
                      ) => HomeDashboardBody(
                        firstName: 'Hellen',
                        environment: AppEnvironment.development,
                        valuesVisible: visible,
                        workspace:
                            workspace ??
                            AsyncData<FinancialWorkspace>(_workspace()),
                        payables:
                            payables ??
                            AsyncData<FinancialCommitmentsState<Payable>>(
                              FinancialCommitmentsState<Payable>(
                                commitments: <Payable>[
                                  createTestPayable(
                                    dueDate: SaoPauloCivilDate(
                                      year: 2026,
                                      month: 8,
                                      day: 10,
                                    ),
                                  ),
                                ],
                                isServerConfirmed: true,
                              ),
                            ),
                        receivables:
                            receivables ??
                            AsyncData<FinancialCommitmentsState<Receivable>>(
                              FinancialCommitmentsState<Receivable>(
                                commitments: <Receivable>[
                                  createTestReceivable(),
                                ],
                                isServerConfirmed: true,
                              ),
                            ),
                        today: today,
                        filter: selectedFilter,
                        onFilterChanged: (HomeDashboardFilter value) =>
                            filter.value = value,
                        callbacks: tracker.callbacks(
                          onToggleValues: () =>
                              visibility.value = !visibility.value,
                        ),
                        onRefresh: tracker.refresh,
                      ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

FinancialWorkspace _workspace({
  int openingBalanceCents = 100000,
  List<FinancialAccount>? accounts,
  List<FinancialCategory>? categories,
  List<FinancialTransaction>? transactions,
}) {
  final List<FinancialAccount> effectiveAccounts =
      accounts ??
      <FinancialAccount>[
        createTestAccount(openingBalanceCents: openingBalanceCents),
      ];
  final List<FinancialCategory> effectiveCategories =
      categories ??
      <FinancialCategory>[
        createTestCategory(),
        createTestCategory(
          id: 'expense-category',
          name: 'Moradia',
          kind: FinancialCategoryKind.expense,
          icon: FinancialCategoryIcon.home,
          color: FinancialCategoryColor.blue,
        ),
      ];
  final List<FinancialTransaction> effectiveTransactions =
      transactions ??
      <FinancialTransaction>[
        createTestTransaction(),
        createTestTransaction(
          id: 'transaction-expense',
          categoryId: 'expense-category',
          kind: FinancialTransactionKind.expense,
          description: 'Mercado do mês',
          amountCents: 50000,
          occurredAt: DateTime.utc(2026, 8, 5, 3),
        ),
      ];
  return FinancialWorkspace(
    accounts: FinancialAccountsState(
      accounts: effectiveAccounts,
      isServerConfirmed: true,
    ),
    categories: FinancialCategoriesState(
      categories: effectiveCategories,
      isServerConfirmed: true,
    ),
    transactions: FinancialTransactionsState(
      transactions: effectiveTransactions,
      isServerConfirmed: true,
    ),
    summary: AccountBalanceCalculator.calculate(
      accounts: effectiveAccounts,
      transactions: effectiveTransactions,
      now: DateTime.utc(2026, 8, 15, 15),
    ),
  );
}

Future<void> _reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    260,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Semantics && widget.properties.label == label,
);

Finder _menuItem(String label) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label));

final class _DashboardTracker {
  int newIncome = 0;
  int newExpense = 0;
  int newPayable = 0;
  int newReceivable = 0;
  int receivables = 0;
  int investments = 0;
  int retryWorkspace = 0;
  int toggleTheme = 0;
  int accounts = 0;
  int categories = 0;
  int transactions = 0;
  int payables = 0;
  int profile = 0;
  int appearance = 0;
  String? transactionId;

  HomeDashboardCallbacks callbacks({required VoidCallback onToggleValues}) =>
      HomeDashboardCallbacks(
        onToggleValues: onToggleValues,
        onToggleTheme: () => toggleTheme += 1,
        onProfile: () => profile += 1,
        onAppearance: () => appearance += 1,
        onAccounts: () => accounts += 1,
        onCategories: () => categories += 1,
        onTransactions: () => transactions += 1,
        onNewIncome: () => newIncome += 1,
        onNewExpense: () => newExpense += 1,
        onNewPayable: () => newPayable += 1,
        onNewReceivable: () => newReceivable += 1,
        onPayables: () => payables += 1,
        onReceivables: () => receivables += 1,
        onInvestments: () => investments += 1,
        onTransaction: (String value) => transactionId = value,
        onRetryWorkspace: () => retryWorkspace += 1,
        onRetryCommitments: () {},
      );

  Future<void> refresh() async {}
}
