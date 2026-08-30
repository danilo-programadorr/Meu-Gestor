import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/rankings_page.dart';

void main() {
  testWidgets(
    'Rankings exibe métricas objetivas indisponíveis sem inventar ranking',
    (WidgetTester tester) async {
      final GoRouter router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rankings'), findsOneWidget);
      expect(find.text('Capitalização'), findsOneWidget);
      expect(find.text('Preço-teto Bazin'), findsOneWidget);
      expect(find.text('Dados de mercado indisponíveis'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('não constituem recomendação'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('não constituem recomendação'),
        findsOneWidget,
      );
      expect(find.text('Indisponível'), findsNWidgets(9));
    },
  );

  testWidgets('filtros preservam regras de FII e BDR sem dados artificiais', (
    WidgetTester tester,
  ) async {
    final GoRouter router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('FIIs'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Número de Graham não se aplica a FIIs'),
      findsOneWidget,
    );
    expect(find.text('Referência patrimonial FII'), findsOneWidget);

    await tester.tap(find.text('BDRs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BDRs aguardam normalização'), findsNWidgets(9));
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

    expect(find.text('Indicadores por fundamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => const RankingsPage()),
  ],
);
