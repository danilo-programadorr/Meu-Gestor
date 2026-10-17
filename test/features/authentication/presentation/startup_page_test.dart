import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/startup_page.dart';

void main() {
  testWidgets('exibe imagem estática e onda central durante o acesso seguro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StartupPage()));

    expect(
      find.byKey(const ValueKey<String>('startup-static-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('startup-dot-wave')),
      findsOneWidget,
    );
    expect(find.text('Preparando seu espaço financeiro'), findsOneWidget);
    expect(find.text('Só mais um instante...'), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantém estado estático quando animações estão reduzidas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StartupPage(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('startup-dot-wave')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
