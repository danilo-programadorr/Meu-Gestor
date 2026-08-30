import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/fair_value.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/fair_value_page.dart';

void main() {
  testWidgets('não apresenta preço justo sem dados automáticos validados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const FairValuePage()));

    expect(
      find.text('Aguardando dados fundamentais validados.'),
      findsOneWidget,
    );
    expect(find.textContaining('não é recomendação'), findsOneWidget);
  });

  testWidgets('explica que BDR não recebe Graham sem normalização', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        FairValuePage(
          snapshot: FairValueSnapshot(
            kind: FairValueAssetKind.bdr,
            currencyCode: 'BRL',
            sourceAt: DateTime.utc(2026, 8, 28),
            quoteCents: 100,
          ),
        ),
      ),
    );

    expect(find.textContaining('BDR aguardando normalização'), findsOneWidget);
  });
}

Widget _testApp(Widget page) {
  final GoRouter router = GoRouter(
    initialLocation: '/preco-justo',
    routes: <RouteBase>[
      GoRoute(path: '/preco-justo', builder: (_, _) => page),
      GoRoute(path: '/investimentos/ferramentas', builder: (_, _) => page),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}
