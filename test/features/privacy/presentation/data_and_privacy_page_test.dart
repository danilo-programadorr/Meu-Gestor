import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/pages/data_and_privacy_page.dart';

void main() {
  testWidgets('separa reset e exclusão e exige a frase aprovada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DataAndPrivacyPage())),
    );
    expect(find.text('Resetar dados financeiros'), findsOneWidget);
    expect(find.text('Excluir permanentemente minha conta'), findsOneWidget);
  });
}
