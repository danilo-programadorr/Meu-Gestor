import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_tools_page.dart';

void main() {
  testWidgets(
    'ferramentas explicam escopo, acessibilidade e ausência de recomendação',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const InvestmentToolsPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      expect(find.text('Calculadoras e análises'), findsOneWidget);
      expect(find.text('Primeiro milhão'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Análise manual de ações e FIIs'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Análise manual de ações e FIIs'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Não são recomendação'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Não são recomendação'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resultado detalhado abre em modal acessível e fecha pelo X', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentToolsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder firstMillion = find.byKey(
      const ValueKey<String>('investment-tool-open-firstMillion'),
    );
    await tester.ensureVisible(firstMillion);
    await tester.pumpAndSettle();
    await tester.tap(firstMillion);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey<String>('investment-tool-field-Valor inicial (R\$)'),
      ),
      '1000',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('investment-tool-field-Aporte mensal (R\$)'),
      ),
      '500',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>(
          'investment-tool-field-Rentabilidade mensal estimada (%)',
        ),
      ),
      '1,00',
    );
    final Finder calculate = find.byKey(
      const ValueKey<String>('investment-tool-calculate-Primeiro milhão'),
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    // A fonte ampliada desloca o botão alguns pixels para fora do viewport.
    // Role a ListView da própria página antes do toque para validar o modal
    // sem depender de um ponto de toque fora da área visível.
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    expect(
      find.text('Resultado — prazo para o primeiro milhão'),
      findsOneWidget,
    );
    expect(find.text('Saldo final estimado'), findsOneWidget);
    expect(find.byTooltip('Fechar resultado'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('investment-result-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resultado — prazo para o primeiro milhão'), findsNothing);
  });

  testWidgets('primeiro milhão descobre aporte por anos e meses', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentToolsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('investment-tool-open-firstMillion')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descobrir aporte'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('investment-tool-field-Valor inicial (R\$)'),
      ),
      '0',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>(
          'investment-tool-field-Rentabilidade mensal estimada (%)',
        ),
      ),
      '0',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('investment-tool-field-Prazo desejado — anos'),
      ),
      '1',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('investment-tool-field-Prazo adicional — meses'),
      ),
      '0',
    );
    final Finder calculate = find.byKey(
      const ValueKey<String>('investment-tool-calculate-Primeiro milhão'),
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    expect(
      find.text('Resultado — aporte para o primeiro milhão'),
      findsOneWidget,
    );
    expect(find.text('Aporte mínimo ao fim de cada mês'), findsOneWidget);
    expect(find.text('1 ano'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('central agrupa ferramentas e mantém apenas uma aberta', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentToolsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('O que você quer calcular?'), findsOneWidget);
    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Cálculos rápidos'), findsOneWidget);
    expect(find.text('Valor inicial (R\$)'), findsNothing);

    final Finder firstMillion = find.byKey(
      const ValueKey<String>('investment-tool-open-firstMillion'),
    );
    await tester.ensureVisible(firstMillion);
    await tester.pumpAndSettle();
    await tester.tap(firstMillion);
    await tester.pumpAndSettle();

    expect(find.text('Valor inicial (R\$)'), findsOneWidget);
    expect(find.text('Juros compostos'), findsNothing);
    expect(find.text('Todas as calculadoras'), findsOneWidget);
  });

  testWidgets('validação aparece no campo e limpar remove entradas', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentToolsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('investment-tool-open-firstMillion')),
    );
    await tester.pumpAndSettle();

    final Finder calculate = find.byKey(
      const ValueKey<String>('investment-tool-calculate-Primeiro milhão'),
    );
    await tester.ensureVisible(calculate);
    await tester.pumpAndSettle();
    await tester.tap(calculate);
    await tester.pumpAndSettle();

    expect(find.text('Informe um valor monetário válido.'), findsNWidgets(2));
    expect(find.text('Não foi possível calcular'), findsNothing);

    final Finder initial = find.byKey(
      const ValueKey<String>('investment-tool-field-Valor inicial (R\$)'),
    );
    await tester.enterText(initial, '1000');
    final Finder clear = find.byKey(
      const ValueKey<String>('investment-tool-clear-Primeiro milhão'),
    );
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(initial).controller!.text, isEmpty);
  });

  testWidgets('privacidade oculta também os valores monetários digitados', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentToolsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('investment-tool-open-firstMillion')),
    );
    await tester.pumpAndSettle();

    final Finder moneyField = find.byKey(
      const ValueKey<String>('investment-tool-field-Valor inicial (R\$)'),
    );
    expect(tester.widget<TextField>(moneyField).obscureText, isFalse);

    await tester.tap(find.byTooltip('Ocultar valores e quantidades'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(moneyField).obscureText, isTrue);
    expect(
      find.text('Valores monetários digitados e resultados estão ocultos.'),
      findsOneWidget,
    );
  });
}
