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
      expect(find.textContaining('Não são recomendação'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(find.text('Análise manual de ações e FIIs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resultado detalhado abre em modal acessível e fecha pelo X', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1200));
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('investment-tool-field-Valor inicial')),
      '1000',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('investment-tool-field-Aporte mensal')),
      '500',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey<String>(
          'investment-tool-field-Rentabilidade mensal (%)',
        ),
      ),
      '100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Calcular').first);
    await tester.pumpAndSettle();

    expect(find.text('Resultado — primeiro milhão'), findsOneWidget);
    expect(find.text('Saldo estimado'), findsOneWidget);
    expect(find.byTooltip('Fechar resultado'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('investment-result-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resultado — primeiro milhão'), findsNothing);
  });
}
