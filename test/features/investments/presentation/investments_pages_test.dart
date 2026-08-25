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
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_details_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_income_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_operation_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_portfolio_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investments_page.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/widgets/investment_premium_route_gate.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_investment_repository.dart';
import '../../../support/fake_premium_entitlement_repository.dart';
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

  testWidgets('exibe seletor e as quatro abas autorizadas', (
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
    expect(find.text('Proventos'), findsOneWidget);
    expect(find.text('Rentabilidade'), findsNothing);
    expect(find.textContaining('patrimônio atual'), findsNothing);
    expect(find.textContaining('valorização'), findsNothing);
    expect(find.byTooltip('Criar carteira'), findsOneWidget);
    expect(find.byTooltip('Gerenciar carteiras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lixeira ao lado da edição exclui somente após frase exata', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _WidgetContext context = await _context();
    addTearDown(context.dispose);
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    context.repository.portfolios.add(
      InvestmentPortfolio(
        id: 'portfolio-empty',
        ownerId: 'owner',
        name: 'Carteira vazia',
        description: '',
        isArchived: false,
        archivedAt: null,
        hasHistory: false,
        createdAt: now,
        updatedAt: now,
        schemaVersion: InvestmentPortfolio.currentSchemaVersion,
        revision: 1,
      ),
    );
    await context.container
        .read(investmentsControllerProvider.notifier)
        .refresh();
    await _pump(tester, context, const InvestmentsPage());

    await tester.tap(find.byTooltip('Gerenciar carteiras'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Editar Carteira vazia'), findsOneWidget);
    expect(find.byTooltip('Excluir Carteira vazia'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('delete-investment-portfolio-portfolio-empty'),
      ),
    );
    await tester.pumpAndSettle();
    final Finder deleteButton = find.widgetWithText(
      FilledButton,
      'Excluir permanentemente',
    );
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('delete-investment-portfolio-confirmation'),
      ),
      'EXCLUIR',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(context.repository.portfolios, isEmpty);
    expect(find.text('Carteira vazia'), findsNothing);
    expect(
      find.text('Carteira vazia excluída permanentemente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('entitlement encerrado não limita investimentos gratuitos', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(
      withOperations: true,
      entitlement: syntheticPremiumEntitlement(
        status: PremiumEntitlementStatus.expired,
      ),
    );
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    expect(find.textContaining('acesso Premium terminou'), findsNothing);
    expect(find.text('Custo atual acompanhado'), findsOneWidget);
    expect(find.byTooltip('Criar carteira'), findsOneWidget);
    expect(find.byTooltip('Gerenciar carteiras'), findsOneWidget);
    expect(find.byTooltip('Consultar carteiras'), findsNothing);
    await _tapInvestmentTab(tester, 'Ativos');
    expect(find.text('Adicionar ativo'), findsOneWidget);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('capability antiga não limita consulta gratuita de proventos', (
    WidgetTester tester,
  ) async {
    final _WidgetContext context = await _context(
      withIncome: true,
      entitlement: syntheticPremiumEntitlement(
        capabilities: const <PremiumCapability>{
          PremiumCapability.investmentsManual,
        },
      ),
    );
    addTearDown(context.dispose);
    await _pump(tester, context, const InvestmentsPage());

    await _tapInvestmentTab(tester, 'Proventos');
    expect(find.textContaining('acesso Premium'), findsNothing);
    expect(context.repository.lastIncludeIncome, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rota direta de mutação encerrada não constrói conteúdo protegido',
    (WidgetTester tester) async {
      final _WidgetContext context = await _context(
        entitlement: syntheticPremiumEntitlement(
          status: PremiumEntitlementStatus.expired,
        ),
      );
      addTearDown(context.dispose);
      await _pump(
        tester,
        context,
        const InvestmentPremiumRouteGate(
          capability: PremiumCapability.investmentsManual,
          intent: PremiumAccessIntent.mutate,
          fallbackLocation: '/',
          child: Text('CONTEUDO_PROTEGIDO'),
        ),
      );

      expect(find.text('Somente consulta'), findsOneWidget);
      expect(find.text('CONTEUDO_PROTEGIDO'), findsNothing);
      expect(
        find.textContaining('dados continuam preservados'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('gate mantém loading estável sem construir dados protegidos', (
    WidgetTester tester,
  ) async {
    final Completer<void> premiumBarrier = Completer<void>();
    final _WidgetContext context = await _context(
      waitForInvestments: false,
      premiumReadBarrier: premiumBarrier,
    );
    addTearDown(context.dispose);
    await _pump(
      tester,
      context,
      const InvestmentPremiumRouteGate(
        capability: PremiumCapability.investmentsManual,
        intent: PremiumAccessIntent.read,
        fallbackLocation: '/',
        child: Text('CONTEUDO_APOS_LOADING'),
      ),
      settle: false,
    );

    expect(find.bySemanticsLabel('Confirmando acesso Premium'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('CONTEUDO_APOS_LOADING'), findsNothing);
    premiumBarrier.complete();
    await tester.pumpAndSettle();
    expect(find.text('CONTEUDO_APOS_LOADING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha de confirmação oferece retry seguro em tela pequena e escura',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final _WidgetContext context = await _context(
        waitForInvestments: false,
        premiumFailure: const PremiumEntitlementFailure(
          kind: PremiumEntitlementFailureKind.unavailable,
          safeMessage: 'Confirmação indisponível.',
          code: 'synthetic_unavailable',
        ),
      );
      addTearDown(context.dispose);
      await _pump(
        tester,
        context,
        const InvestmentPremiumRouteGate(
          capability: PremiumCapability.investmentsManual,
          intent: PremiumAccessIntent.read,
          fallbackLocation: '/',
          child: Text('CONTEUDO_CONFIRMADO'),
        ),
        theme: AppTheme.dark,
        textScaler: const TextScaler.linear(1.8),
      );

      expect(find.text('Confirmação indisponível'), findsOneWidget);
      expect(find.text('CONTEUDO_CONFIRMADO'), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('CONTEUDO_CONFIRMADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

    await _tapInvestmentTab(tester, 'Lançamentos');
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

  testWidgets(
    'proventos apresenta dados reais, gráficos, filtros e transições seguras',
    (WidgetTester tester) async {
      final _WidgetContext context = await _context(withIncome: true);
      addTearDown(context.dispose);
      await _pump(tester, context, const InvestmentsPage());

      await _tapInvestmentTab(tester, 'Proventos');
      expect(find.text('Resumo do período'), findsOneWidget);
      expect(find.text('Filtros'), findsOneWidget);
      final Finder incomeScroll = find.descendant(
        of: find.byKey(const ValueKey<String>('investment-income-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Recebido versus previsto'),
        220,
        scrollable: incomeScroll,
      );
      expect(find.text('Recebido versus previsto'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Distribuição por ativo'),
        220,
        scrollable: incomeScroll,
      );
      expect(find.text('Distribuição por ativo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Meus proventos'),
        220,
        scrollable: incomeScroll,
      );
      expect(find.text('Meus proventos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PETR4 · Juros sobre capital próprio'),
        220,
        scrollable: incomeScroll,
      );
      expect(find.text('PETR4 · Dividendo'), findsOneWidget);
      expect(find.text('PETR4 · Juros sobre capital próprio'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Receber'),
        220,
        scrollable: incomeScroll,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Receber'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar recebimento?'), findsOneWidget);
      expect(
        find.textContaining('Nenhuma conta ou saldo será alterado'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(
        context.repository.incomeEvents
            .where(
              (InvestmentIncomeEvent event) =>
                  event.status == InvestmentIncomeStatus.received,
            )
            .length,
        2,
      );
      await tester.scrollUntilVisible(
        find.text('Histórico'),
        220,
        scrollable: incomeScroll,
      );
      expect(find.text('Histórico'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'aba de proventos cabe em 320 px com fonte ampliada e privacidade',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final _WidgetContext context = await _context(withIncome: true);
      addTearDown(context.dispose);
      await _pump(
        tester,
        context,
        const InvestmentsPage(),
        textScaler: const TextScaler.linear(1.8),
      );

      await _tapInvestmentTab(tester, 'Proventos');
      await tester.tap(find.byTooltip('Ocultar valores e quantidades'));
      await tester.pump();
      expect(find.text('••••'), findsWidgets);
      expect(
        find.bySemanticsLabel('Resumo de proventos com valores ocultos.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('proventos preserva estado vazio e temas claro e escuro', (
    WidgetTester tester,
  ) async {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final _WidgetContext context = await _context(withAsset: true);
      await _pump(tester, context, const InvestmentsPage(), theme: theme);
      await _tapInvestmentTab(tester, 'Proventos');
      final Finder incomeScroll = find.descendant(
        of: find.byKey(const ValueKey<String>('investment-income-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Nenhum provento manual nesta carteira.'),
        220,
        scrollable: incomeScroll,
      );
      expect(
        find.text('Nenhum provento manual nesta carteira.'),
        findsOneWidget,
      );
      expect(find.text('Adicionar provento'), findsOneWidget);
      expect(tester.takeException(), isNull);
      context.dispose();
    }
  });

  testWidgets(
    'formulário calcula prévia real e permanece utilizável com teclado',
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
        const InvestmentIncomeFormPage(portfolioId: 'portfolio-1'),
        textScaler: const TextScaler.linear(1.8),
      );

      final Finder formScroll = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('investment-income-form-scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final Finder grossField = find.widgetWithText(
        TextFormField,
        'Valor bruto total',
      );
      await tester.scrollUntilVisible(grossField, 180, scrollable: formScroll);
      await tester.enterText(grossField, '100,00');
      await tester.scrollUntilVisible(
        find.text('Valor líquido'),
        220,
        scrollable: formScroll,
      );
      expect(find.text('R\$ 100,00'), findsWidgets);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Criar previsão'),
        220,
        scrollable: formScroll,
      );
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
  bool withIncome = false,
  Completer<void>? readBarrier,
  bool waitForInvestments = true,
  PremiumEntitlement? entitlement,
  Object? premiumFailure,
  Completer<void>? premiumReadBarrier,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeInvestmentRepository repository = FakeInvestmentRepository();
  final FakePremiumEntitlementRepository premiumRepository =
      FakePremiumEntitlementRepository(
          entitlement: entitlement ?? syntheticPremiumEntitlement(),
        )
        ..nextFailure = premiumFailure
        ..readBarrier = premiumReadBarrier;
  repository.readBarrier = readBarrier;
  if (withAsset || withOperations || withIncome) {
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
    if (withIncome) {
      repository.incomeEvents.addAll(<InvestmentIncomeEvent>[
        _incomeEvent(
          id: 'income-expected',
          type: InvestmentIncomeType.dividend,
          status: InvestmentIncomeStatus.expected,
          expectedPaymentDate: DateTime.utc(2026, 8, 8, 3),
          grossAmountCents: 10000,
          withholdingTaxCents: 0,
        ),
        _incomeEvent(
          id: 'income-received',
          type: InvestmentIncomeType.jcp,
          status: InvestmentIncomeStatus.received,
          expectedPaymentDate: DateTime.utc(2026, 7, 20, 3),
          receivedDate: DateTime.utc(2026, 7, 21, 3),
          grossAmountCents: 20000,
          withholdingTaxCents: 3000,
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
      premiumEntitlementRepositoryProvider.overrideWithValue(premiumRepository),
      premiumAccessReferenceClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 10, 12),
      ),
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

InvestmentIncomeEvent _incomeEvent({
  required String id,
  required InvestmentIncomeType type,
  required InvestmentIncomeStatus status,
  required DateTime expectedPaymentDate,
  DateTime? receivedDate,
  required int grossAmountCents,
  required int withholdingTaxCents,
}) {
  final DateTime createdAt = DateTime.utc(2026, 7, 1, 12);
  return InvestmentIncomeEvent(
    id: id,
    ownerId: 'owner',
    portfolioId: 'portfolio-1',
    assetId: 'portfolio-1__PETR4',
    type: type,
    status: status,
    inputMode: InvestmentIncomeInputMode.total,
    exDate: null,
    expectedPaymentDate: expectedPaymentDate,
    receivedDate: receivedDate,
    eligibleQuantityScaled: null,
    unitAmountScaled: null,
    grossAmountCents: grossAmountCents,
    withholdingTaxCents: withholdingTaxCents,
    netAmountCents: grossAmountCents - withholdingTaxCents,
    notes: '',
    originType: InvestmentIncomeOriginType.manual,
    externalId: null,
    cancelledAt: null,
    voidedAt: null,
    mutationId: 'mutation-$id',
    createdAt: createdAt,
    updatedAt: createdAt,
    schemaVersion: 1,
    revision: 1,
  );
}

Future<void> _tapInvestmentTab(WidgetTester tester, String label) async {
  final Finder tab = find.text(label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
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
