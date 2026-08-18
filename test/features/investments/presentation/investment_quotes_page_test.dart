import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_performance.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_quotes_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_quotes_page.dart';

void main() {
  testWidgets('cotações indisponíveis não inventam valores em tela pequena', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const InvestmentQuotesPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          investmentPortfolioPerformanceProvider.overrideWith(
            (Ref ref) => const InvestmentPortfolioPerformance(
              positions: <InvestmentPositionPerformance>[],
              quotedAssetCount: 0,
              totalAssetCount: 0,
              estimatedMarketValueCents: null,
              unrealizedResultCents: null,
              realizedResultCents: 0,
              receivedIncomeCents: 0,
              totalEconomicResultCents: null,
            ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cotações e rentabilidade'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Cotações indisponíveis'), findsOneWidget);
    expect(find.text('Indisponível'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
