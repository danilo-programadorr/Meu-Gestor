import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/rankings_page.dart';

void main() {
  testWidgets(
    'Rankings usa um único estado de preparação sem inventar posições',
    (WidgetTester tester) async {
      final GoRouter router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rankings'), findsOneWidget);
      expect(find.text('Explore indicadores'), findsOneWidget);
      expect(find.text('Rankings de Ações em preparação'), findsOneWidget);
      expect(find.text('Fonte fundamentalista: Não integrada'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Indicadores previstos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Indicadores previstos'), findsOneWidget);
      expect(find.text('Capitalização'), findsOneWidget);
      expect(find.text('Referência patrimonial FII'), findsNothing);
      expect(find.text('Indisponível'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('não constituem recomendação'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('não constituem recomendação'),
        findsOneWidget,
      );
    },
  );

  testWidgets('filtros mostram somente indicadores compatíveis', (
    WidgetTester tester,
  ) async {
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('ranking-filter-fiis')));
    await tester.pumpAndSettle();
    final Finder fiiSummary = find.textContaining(
      '8 métricas compatíveis com FIIs',
    );
    await tester.scrollUntilVisible(
      fiiSummary,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(fiiSummary, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Referência patrimonial FII'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Referência patrimonial FII'), findsOneWidget);
    expect(find.text('Diferença versus Graham'), findsNothing);

    final Finder bdrs = find.byKey(
      const ValueKey<String>('ranking-filter-bdrs'),
    );
    await tester.scrollUntilVisible(
      bdrs,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(bdrs);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('BDRs precisam de normalização adicional'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('BDRs precisam de normalização adicional'),
      findsOneWidget,
    );
    expect(find.text('Indicadores previstos'), findsNothing);
  });

  testWidgets('oferece caminhos úteis sem apresentar ranking artificial', (
    WidgetTester tester,
  ) async {
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final Finder tools = find.byKey(
      const ValueKey<String>('ranking-open-tools'),
    );
    await tester.scrollUntilVisible(
      tools,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tools);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tools-route')), findsOneWidget);
  });

  testWidgets('suporta 320 px e fonte ampliada sem overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explore indicadores'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ranking-filter-bdrs')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/rankings',
  routes: <RouteBase>[
    GoRoute(path: '/rankings', builder: (_, _) => const RankingsPage()),
    GoRoute(
      path: '/investimentos',
      builder: (_, _) => const Scaffold(body: Text('Investimentos')),
    ),
    GoRoute(
      path: '/investimentos/ferramentas',
      builder: (_, _) => const Scaffold(
        body: Text('Ferramentas', key: ValueKey<String>('tools-route')),
      ),
    ),
    GoRoute(
      path: '/investimentos/cotacoes',
      builder: (_, _) => const Scaffold(body: Text('Cotações')),
    ),
  ],
);
