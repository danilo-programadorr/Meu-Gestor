import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/navigation/global_quick_navigation.dart';

void main() {
  testWidgets(
    'mantém cinco atalhos globais, com rótulos, e navega para a conversa',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/contas',
        routes: <RouteBase>[
          GoRoute(
            path: '/contas',
            builder: (_, _) => const Scaffold(body: Text('Interna')),
          ),
          GoRoute(
            path: '/assistente/conversa',
            builder: (_, _) => const Scaffold(
              body: Text('Conversa', key: Key('conversation-route')),
            ),
          ),
          GoRoute(
            path: '/investimentos',
            builder: (_, _) => const Scaffold(body: Text('Investimentos')),
          ),
          GoRoute(
            path: '/investimentos/rankings',
            builder: (_, _) => const Scaffold(body: Text('Rankings')),
          ),
          GoRoute(
            path: '/investimentos/ferramentas',
            builder: (_, _) => const Scaffold(body: Text('Calculadoras')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (BuildContext context, Widget? child) =>
              GlobalQuickNavigation(
                router: router,
                location: '/contas',
                onNavigate: router.go,
                child: child ?? const SizedBox.shrink(),
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick-nav-Home')), findsOneWidget);
      expect(find.byKey(const Key('quick-nav-Ranking')), findsOneWidget);
      expect(find.byKey(const Key('quick-nav-Conversa')), findsOneWidget);
      expect(find.byKey(const Key('quick-nav-Investimentos')), findsOneWidget);
      expect(find.byKey(const Key('quick-nav-Calculadora')), findsOneWidget);
      expect(find.text('Ranking'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('quick-nav-Conversa')),
          matching: find.text('Conversa'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('quick-nav-Conversa')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conversation-route')), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.queryParameters, {
        'listen': 'auto',
      });
    },
  );

  testWidgets('não sobrepõe modal nas calculadoras', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/investimentos/ferramentas',
      routes: <RouteBase>[
        GoRoute(
          path: '/investimentos/ferramentas',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    GlobalQuickNavigationModalVisibility.whileModalIsOpen(
                      () => showDialog<void>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Resultado detalhado'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                child: const Text('Abrir resultado'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => GlobalQuickNavigation(
          router: router,
          location: '/investimentos/ferramentas',
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-nav-Home')), findsOneWidget);
    await tester.tap(find.text('Abrir resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado detalhado'), findsOneWidget);
    expect(find.byKey(const Key('quick-nav-Home')), findsNothing);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado detalhado'), findsNothing);
    expect(find.byKey(const Key('quick-nav-Home')), findsOneWidget);
  });

  testWidgets('não aparece em rota anterior à autenticação', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Entrar')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => GlobalQuickNavigation(
          router: router,
          location: '/login',
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-nav-Home')), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
