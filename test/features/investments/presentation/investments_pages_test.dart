import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_details_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_operation_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_portfolio_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investments_page.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_investment_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
    'estado vazio explica acompanhamento manual sem dados fictícios',
    (WidgetTester tester) async {
      final _WidgetContext context = await _context();
      addTearDown(context.dispose);
      await _pump(tester, context, const InvestmentsPage());

      expect(find.text('Investimentos'), findsOneWidget);
      expect(find.text('Acompanhamento manual'), findsOneWidget);
      expect(
        find.text('Crie sua primeira carteira de acompanhamento'),
        findsOneWidget,
      );
      expect(find.textContaining('Cotações automáticas'), findsOneWidget);
      expect(find.textContaining(r'R$ 10.000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('posição cabe em 320 px, respeita fonte ampliada e privacidade', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _WidgetContext context = await _context(withAsset: true);
    addTearDown(context.dispose);
    await _pump(
      tester,
      context,
      const InvestmentsPage(),
      textScaler: const TextScaler.linear(1.8),
    );

    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PETR4'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey<String>('investments-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PETR4'), findsOneWidget);
    expect(find.text('Posição zerada'), findsOneWidget);
    await tester.tap(find.byTooltip('Ocultar valores e quantidades'));
    await tester.pump();
    expect(find.text('••••'), findsWidgets);
    expect(context.container.read(financialPrivacyControllerProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe não inventa cotação e bloqueia venda sem posição', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(withAsset: true);
    addTearDown(context.dispose);
    await _pump(
      tester,
      context,
      const InvestmentAssetDetailsPage(assetId: 'portfolio-1__PETR4'),
    );

    expect(
      find.text('Cotação automática ainda não disponível'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Nenhuma operação registrada. Comece pela operação mais antiga.',
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButtonIcon), findsOneWidget);
    final OutlinedButton sell = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Registrar venda'),
    );
    expect(sell.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulário de carteira apresenta validação compreensível', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context();
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentPortfolioFormPage());

    await tester.tap(find.text('Criar carteira'));
    await tester.pump();
    expect(
      find.text('Informe um nome de carteira com até 60 caracteres.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('página renderiza nos temas claro e escuro', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final _WidgetContext context = await _context(withAsset: true);
      await _pump(tester, context, const InvestmentsPage(), theme: theme);
      expect(
        find.byKey(const ValueKey<String>('investment-main-summary-card')),
        findsOneWidget,
      );
      expect(find.text('Custo atual acompanhado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      context.dispose();
    }
  });

  testWidgets('exibe seletor e somente as três abas autorizadas', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(withAsset: true);
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    expect(
      find.byKey(const ValueKey<String>('investment-portfolio-selector')),
      findsOneWidget,
    );
    expect(find.text('Resumo'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(find.text('Proventos'), findsNothing);
    expect(find.text('Rentabilidade'), findsNothing);
    expect(find.textContaining('patrimônio atual'), findsNothing);
    expect(find.textContaining('valorização'), findsNothing);
    expect(find.byTooltip('Criar carteira'), findsOneWidget);
    expect(find.byTooltip('Gerenciar carteiras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo usa operações reais nos gráficos e nas classes', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(withOperations: true);
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    expect(find.text('Evolução dos aportes e vendas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('investment-evolution-chart')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('investment-allocation-chart')),
      220,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('investment-summary-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('investment-allocation-chart')),
      findsOneWidget,
    );
    expect(find.text('Ação'), findsWidgets);
    expect(find.text('Fundo imobiliário'), findsWidgets);
    expect(find.textContaining('cotação de mercado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca e filtro de ativos funcionam localmente', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(withOperations: true);
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    await tester.tap(find.text('Ativos'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('investment-asset-search')),
      'petrobras',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('PETR4'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey<String>('investments-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PETR4'), findsOneWidget);
    expect(find.text('HGLG11'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('investment-asset-search')),
      -200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey<String>('investments-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('investment-asset-search')),
      '',
    );
    await tester.tap(find.widgetWithText(FilterChip, 'FIIs'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('HGLG11'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey<String>('investments-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('HGLG11'), findsOneWidget);
    expect(find.text('PETR4'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lançamentos exibem dados e estado sem tabela horizontal', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _WidgetContext context = await _context(withOperations: true);
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Compra · HGLG11'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('investment-operations-scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Compra · PETR4'), findsOneWidget);
    expect(find.text('Compra · HGLG11'), findsOneWidget);
    expect(find.text('Total pago'), findsWidgets);
    expect(find.text('Ativa'), findsWidgets);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prévia da compra usa aritmética canônica e confirmação', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(withOperations: true);
    addTearDown(context.dispose);
    await _pump(
      tester,
      context,
      const InvestmentOperationFormPage(
        assetId: 'portfolio-1__PETR4',
        initialKind: InvestmentOperationKind.buy,
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço unitário'),
      '40',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Taxas'), '1');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('investment-operation-preview')),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('investment-operation-form-scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('R\$ 40,00'), findsOneWidget);
    expect(find.text('R\$ 1,00'), findsOneWidget);
    expect(find.text('R\$ 41,00'), findsOneWidget);
    expect(find.text('R\$ 31,090909'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Revisar e confirmar compra'),
      220,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('investment-operation-form-scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Revisar e confirmar compra'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirmar compra?'), findsOneWidget);
    expect(find.text('Confirmar operação'), findsOneWidget);
    await tester.tap(find.text('Voltar e revisar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo preserva privacidade e layout com fonte a 180%', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _WidgetContext context = await _context(withOperations: true);
    addTearDown(context.dispose);
    await _pump(
      tester,
      context,
      const InvestmentsPage(),
      textScaler: const TextScaler.linear(1.8),
    );

    await tester.tap(find.byTooltip('Ocultar valores e quantidades'));
    await tester.pump();
    expect(find.text('••••'), findsWidgets);
    expect(context.container.read(financialPrivacyControllerProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro oferece retry e retorna ao estado vazio confirmado', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context();
    addTearDown(context.dispose);
    context.repository.nextReadFailure = const InvestmentFailure(
      kind: InvestmentFailureKind.unavailable,
      safeMessage: 'Servidor temporariamente indisponível.',
      code: 'test_unavailable',
    );
    await context.container
        .read(investmentsControllerProvider.notifier)
        .refresh();
    await _pump(tester, context, const InvestmentsPage());

    expect(find.text('Servidor temporariamente indisponível.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Crie sua primeira carteira de acompanhamento'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('carregamento apresenta progresso com semântica', (
    WidgetTester tester,
  ) async {
    final Completer<void> barrier = Completer<void>();
    final _WidgetContext context = await _context(
      readBarrier: barrier,
      waitForInvestments: false,
    );
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage(), settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando investimentos'), findsOneWidget);
    barrier.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'formulário normaliza ticker e permanece utilizável com teclado',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(() => tester.view.resetViewInsets());
      final _WidgetContext context = await _context(withAsset: true);
      addTearDown(context.dispose);
      await _pump(
        tester,
        context,
        const InvestmentAssetFormPage(portfolioId: 'portfolio-1'),
        textScaler: const TextScaler.linear(1.8),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ticker'),
        'vale3',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do ativo'),
        'Vale ON',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Adicionar ativo'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar ativo'));
      await tester.pumpAndSettle();
      expect(context.repository.assets.last.ticker, 'VALE3');
      expect(tester.takeException(), isNull);
    },
  );
}

final class _WidgetContext {
  const _WidgetContext({
    required this.container,
    required this.auth,
    required this.repository,
    required this.gate,
    required this.investments,
    required this.action,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeInvestmentRepository repository;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate;
  final ProviderSubscription<AsyncValue<InvestmentsState>> investments;
  final ProviderSubscription<InvestmentActionState> action;

  void dispose() {
    action.close();
    investments.close();
    gate.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_WidgetContext> _context({
  bool withAsset = false,
  bool withOperations = false,
  Completer<void>? readBarrier,
  bool waitForInvestments = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeInvestmentRepository repository = FakeInvestmentRepository();
  repository.readBarrier = readBarrier;
  if (withAsset || withOperations) {
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    repository.portfolios.add(
      InvestmentPortfolio(
        id: 'portfolio-1',
        ownerId: 'owner',
        name: 'Longo prazo',
        description: '',
        isArchived: false,
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        revision: 1,
      ),
    );
    repository.assets.add(
      TrackedInvestmentAsset(
        id: 'portfolio-1__PETR4',
        ownerId: 'owner',
        portfolioId: 'portfolio-1',
        ticker: 'PETR4',
        name: 'Petrobras PN',
        type: TrackedInvestmentAssetType.stock,
        currencyCode: 'BRL',
        currentQuantityScaled: withOperations
            ? InvestmentQuantity.parsePtBr('10').scaled
            : 0,
        lastOperationId: withOperations ? 'operation-petr4' : null,
        lastOperationAt: withOperations
            ? InvestmentOperation.fromCalendarDate(DateTime.utc(2026, 8, 1))
            : null,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        revision: 1,
      ),
    );
    if (withOperations) {
      repository.assets.add(
        TrackedInvestmentAsset(
          id: 'portfolio-1__HGLG11',
          ownerId: 'owner',
          portfolioId: 'portfolio-1',
          ticker: 'HGLG11',
          name: 'CSHG Logística',
          type: TrackedInvestmentAssetType.fii,
          currencyCode: 'BRL',
          currentQuantityScaled: InvestmentQuantity.parsePtBr('2').scaled,
          lastOperationId: 'operation-hglg11',
          lastOperationAt: InvestmentOperation.fromCalendarDate(
            DateTime.utc(2026, 7, 1),
          ),
          createdAt: now,
          updatedAt: now,
          schemaVersion: 1,
          revision: 1,
        ),
      );
      repository.operations.addAll(<InvestmentOperation>[
        _operation(
          id: 'operation-petr4',
          assetId: 'portfolio-1__PETR4',
          date: DateTime.utc(2026, 8, 1),
          quantity: '10',
          price: '30',
          feesCents: 100,
        ),
        _operation(
          id: 'operation-hglg11',
          assetId: 'portfolio-1__HGLG11',
          date: DateTime.utc(2026, 7, 1),
          quantity: '2',
          price: '160',
          feesCents: 0,
        ),
      ]);
    }
  }
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      investmentRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final Completer<void> gateReady = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate = container
      .listen(profileGateControllerProvider, (_, next) {
        if (next.value?.isTerminal == true && !gateReady.isCompleted) {
          gateReady.complete();
        }
      }, fireImmediately: true);
  await gateReady.future.timeout(const Duration(seconds: 2));
  final Completer<void> investmentsReady = Completer<void>();
  final ProviderSubscription<AsyncValue<InvestmentsState>> investments =
      container.listen(investmentsControllerProvider, (_, next) {
        if (!next.isLoading && !investmentsReady.isCompleted) {
          investmentsReady.complete();
        }
      }, fireImmediately: true);
  if (waitForInvestments) {
    await investmentsReady.future.timeout(const Duration(seconds: 2));
  }
  final ProviderSubscription<InvestmentActionState> action = container.listen(
    investmentActionControllerProvider,
    (_, _) {},
  );
  return _WidgetContext(
    container: container,
    auth: auth,
    repository: repository,
    gate: gate,
    investments: investments,
    action: action,
  );
}

InvestmentOperation _operation({
  required String id,
  required String assetId,
  required DateTime date,
  required String quantity,
  required String price,
  required int feesCents,
}) {
  final DateTime occurredAt = InvestmentOperation.fromCalendarDate(date);
  return InvestmentOperation(
    id: id,
    ownerId: 'owner',
    portfolioId: 'portfolio-1',
    assetId: assetId,
    previousOperationId: null,
    previousOperationAt: null,
    kind: InvestmentOperationKind.buy,
    occurredAt: occurredAt,
    quantityScaled: InvestmentQuantity.parsePtBr(quantity).scaled,
    unitPriceScaled: InvestmentUnitPrice.parsePtBr(price).scaled,
    feesCents: feesCents,
    notes: '',
    isVoided: false,
    voidedAt: null,
    mutationId: 'mutation-$id',
    createdAt: occurredAt.add(const Duration(hours: 1)),
    updatedAt: occurredAt.add(const Duration(hours: 1)),
    schemaVersion: 1,
    revision: 1,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _WidgetContext context,
  Widget child, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: '/test-page',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox.shrink()),
        routes: <RouteBase>[
          GoRoute(
            path: 'test-page',
            builder: (BuildContext context, GoRouterState state) => child,
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: context.container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.light,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
