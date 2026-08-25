import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_summary_provider.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_page.dart';

void main() {
  testWidgets('sem consentimento exibe escopo e não monta dados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantConsentContent(
            consentEnabled: false,
            valuesVisible: true,
            onManageConsent: () {},
            enabledContent: const Text('CONTEUDO_FINANCEIRO_NAO_DEVE_MONTAR'),
          ),
        ),
      ),
    );

    expect(find.text('Dados usados e protegidos'), findsOneWidget);
    expect(find.text('Consentimento necessário'), findsOneWidget);
    expect(find.text('CONTEUDO_FINANCEIRO_NAO_DEVE_MONTAR'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets(
    'perguntas guiadas exibem fontes, período e resumo determinístico',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [assistantReadModelProvider.overrideWithValue(_model())],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AssistantDataExperience()),
            ),
          ),
        ),
      );

      expect(find.text('Como foi meu mês?'), findsOneWidget);
      expect(find.text('Resumo do mês'), findsOneWidget);
      expect(find.textContaining('America/Sao_Paulo'), findsOneWidget);
      expect(find.textContaining('R\$ 3.000,00'), findsOneWidget);

      await tester.tap(find.text('Quais são minhas pendências?'));
      await tester.pump();

      expect(find.text('Compromissos financeiros'), findsOneWidget);
      expect(find.text('Contas a pagar • leitura confirmada'), findsOneWidget);
      expect(find.textContaining('Pendências não alteram'), findsOneWidget);
    },
  );

  testWidgets('privacidade oculta cifras e contagens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assistantReadModelProvider.overrideWithValue(_model())],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantDataExperience(valuesVisibleOverride: false),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Valor oculto'), findsNWidgets(4));
    expect(find.textContaining('R\$ 3.000,00'), findsNothing);
  });

  testWidgets('conteúdo suporta 320 px e fonte ampliada sem overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(1.8),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: AssistantConsentContent(
              consentEnabled: true,
              valuesVisible: true,
              onManageConsent: () {},
              enabledContent: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('assistant-page-scroll')),
      findsOneWidget,
    );
  });
}

AssistantReadModel _model() => AssistantReadModel(
  snapshot: AssistantReadOnlySnapshot(
    generatedAt: DateTime.utc(2026, 8, 25, 15),
    today: SaoPauloCivilDate(year: 2026, month: 8, day: 25),
    core: const AssistantCoreSnapshot(
      totalBalanceCents: 150000,
      activeAccountCount: 2,
      monthIncomeCents: 300000,
      monthExpenseCents: 180000,
      monthTransactionCount: 5,
    ),
    commitments: const AssistantCommitmentSnapshot(
      pendingPayablesCount: 2,
      pendingPayablesCents: 25000,
      overduePayablesCount: 1,
      overduePayablesCents: 5000,
      pendingReceivablesCount: 1,
      pendingReceivablesCents: 10000,
      overdueReceivablesCount: 0,
      overdueReceivablesCents: 0,
    ),
    investments: const AssistantInvestmentSnapshot(
      activePortfolioCount: 1,
      trackedAssetCount: 2,
      openPositionCount: 2,
      totalCostCents: 100000,
      realizedResultCents: 5000,
      receivedIncomeCents: 2500,
    ),
  ),
  isLoading: false,
  unavailableSources: const {},
);
