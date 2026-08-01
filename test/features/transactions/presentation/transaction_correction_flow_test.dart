import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/app.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/firestore_financial_transaction_mapper.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transaction_action_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/movement_date_field.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/positive_money_input_field.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_kind_selector.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_category_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_category_fixtures.dart';
import '../../../support/financial_transaction_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  testWidgets('15. lançamento ativo mostra edição descritiva', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.text('Editar dados descritivos'), findsOneWidget);
  });

  testWidgets('16. lançamento cancelado não mostra edição', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(
      tester,
      transaction: createTestTransaction(isVoided: true),
    );
    addTearDown(harness.dispose);
    expect(find.text('Editar dados descritivos'), findsNothing);
    expect(find.text('Cancelado — não participa do saldo'), findsWidgets);
  });

  testWidgets('17. rota de edição abre para lançamento ativo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.text('Editar dados descritivos'));
    await tester.pumpAndSettle();
    expect(find.text('Editar lançamento'), findsOneWidget);
  });

  testWidgets('18. acesso direto à edição de cancelado é bloqueado', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      transaction: createTestTransaction(isVoided: true),
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.editTransaction('transaction-1'));
    expect(
      find.text('Este lançamento foi cancelado e não pode ser editado.'),
      findsOneWidget,
    );
    expect(find.text('Salvar alterações'), findsNothing);
  });

  testWidgets('19. tipo, conta e valor permanecem protegidos', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openEdit(tester);
    addTearDown(harness.dispose);
    final TransactionKindSelector kind = tester.widget(
      find.byType(TransactionKindSelector),
    );
    final PositiveMoneyInputField amount = tester.widget(
      find.byType(PositiveMoneyInputField),
    );
    final List<DropdownButtonFormField<String>> dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList(growable: false);
    expect(kind.enabled, isFalse);
    expect(amount.enabled, isFalse);
    expect(dropdowns.first.onChanged, isNull);
    expect(
      find.text(
        'Tipo, conta e valor são protegidos. Para corrigi-los, cancele este lançamento e registre outro.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    '20. descrição, categoria compatível, data e observações são editáveis',
    (WidgetTester tester) async {
      final _Harness harness = await _openEdit(tester);
      addTearDown(harness.dispose);
      await tester.enterText(_field('Descrição'), 'Receita revisada');
      await tester.tap(_dropdown('Categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bônus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Data da movimentação:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Observações (opcional)'), 'Conferida');
      await tester.scrollUntilVisible(
        find.text('Salvar alterações'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final FinancialTransaction updated =
          harness.transactions.transactions.single;
      expect(updated.description, 'Receita revisada');
      expect(updated.categoryId, 'income-bonus');
      expect(updated.occurredAt, DateTime.utc(2026, 8, 2, 3));
      expect(updated.notes, 'Conferida');
      expect(find.text('Detalhes do lançamento'), findsOneWidget);
    },
  );

  testWidgets('21. salvar atualiza lista, detalhes, resumo e saldo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      transaction: createTestTransaction(
        description: 'Receita antiga',
        occurredAt: DateTime.utc(2026, 7, 31, 3),
        amountCents: 10000,
      ),
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.transactionDetails('transaction-1'));
    await harness.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Receita atualizada',
        occurredAt: DateTime.utc(2026, 8, 2, 3),
        notes: 'Atualizada',
      ),
    );
    await tester.pumpAndSettle();
    final FinancialWorkspace workspace = harness.container
        .read(financialWorkspaceProvider)
        .requireValue;
    expect(find.text('Receita atualizada'), findsOneWidget);
    expect(
      workspace.transactions.findById('transaction-1')?.description,
      'Receita atualizada',
    );
    expect(workspace.summary.currentMonth.income.cents, 10000);
    expect(workspace.summary.totalCurrentBalance.cents, 110000);
  });

  testWidgets('22. alterar somente descrição não muda o saldo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    final int before = harness.workspace.summary.totalCurrentBalance.cents;
    await harness.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Descrição nova',
        occurredAt: DateTime.utc(2026, 8, 1, 3),
        notes: '',
      ),
    );
    expect(harness.workspace.summary.totalCurrentBalance.cents, before);
  });

  testWidgets('23. alterar data entre meses recalcula o resumo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(harness.workspace.summary.currentMonth.income.cents, 250000);
    await harness.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Receita movida',
        occurredAt: DateTime.utc(2026, 7, 31, 3),
        notes: '',
      ),
    );
    expect(harness.workspace.summary.currentMonth.income.cents, 0);
  });

  testWidgets('24. lançamento ativo mostra cancelar lançamento', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.text('Cancelar lançamento'), findsOneWidget);
  });

  testWidgets('25. cancelamento exige confirmação', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.text('Cancelar lançamento'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar este lançamento?'), findsOneWidget);
    expect(
      find.text(
        'O lançamento deixará de participar do saldo, mas continuará registrado para preservar o histórico.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(harness.transactions.transactions.single.isVoided, isFalse);
  });

  testWidgets('26. cancelado permanece no histórico', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await _confirmCancellation(tester);
    expect(harness.transactions.transactions, hasLength(1));
    expect(harness.transactions.transactions.single.isVoided, isTrue);
    expect(find.text('Cancelado — não participa do saldo'), findsWidgets);
  });

  testWidgets('27. cancelado não pode ser editado', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await _confirmCancellation(tester);
    expect(find.text('Editar dados descritivos'), findsNothing);
    expect(find.byTooltip('Editar lançamento'), findsNothing);
  });

  testWidgets('28. cancelado não pode ser restaurado', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(
      tester,
      transaction: createTestTransaction(isVoided: true),
    );
    addTearDown(harness.dispose);
    expect(find.textContaining('Restaurar'), findsNothing);
  });

  testWidgets('29. não existe exclusão definitiva de lançamento', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.text('Excluir'), findsNothing);
    expect(find.text('Apagar'), findsNothing);
    expect(find.text('Remover definitivamente'), findsNothing);
  });

  testWidgets('30. lista para detalhes apresenta seta de voltar', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.byTooltip('Voltar'), findsOneWidget);
  });

  testWidgets('31. voltar dos detalhes retorna à lista', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Lançamentos'), findsOneWidget);
    await _revealTransaction(tester, 'Salário mensal');
    expect(find.byType(TransactionCard), findsOneWidget);
  });

  testWidgets('32. voltar da edição retorna aos detalhes', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openEdit(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do lançamento'), findsOneWidget);
  });

  testWidgets('33. voltar do novo lançamento retorna à lista', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openList(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.text('Novo lançamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo do mês atual'), findsOneWidget);
  });

  testWidgets('34. botão físico retorna à tela anterior', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Lançamentos'), findsOneWidget);
  });

  testWidgets('35. detalhes sem pilha usa fallback para lançamentos', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.transactionDetails('transaction-1'));
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Lançamentos'), findsOneWidget);
  });

  testWidgets('36. voltar em tela interna não encerra o aplicativo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(tester);
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.newTransaction);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Resumo do mês atual'), findsOneWidget);
  });

  testWidgets('37. refresh não duplica rotas', (WidgetTester tester) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await harness.container
        .read(financialTransactionsControllerProvider.notifier)
        .refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Lançamentos'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Meu Gestor Financeiro'),
      findsOneWidget,
    );
  });

  testWidgets('38. fonte ampliada mantém botão de voltar', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.byTooltip('Voltar'), findsOneWidget);
  });

  testWidgets('39. tela pequena mantém ações de editar e cancelar', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(find.text('Editar dados descritivos'), findsOneWidget);
    expect(find.text('Cancelar lançamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('40. temas claro e escuro mantêm ações visíveis', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    expect(find.text('Editar dados descritivos'), findsOneWidget);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.onPlatformBrightnessChanged?.call();
    await tester.pumpAndSettle();
    expect(find.text('Editar dados descritivos'), findsOneWidget);
    expect(find.text('Cancelar lançamento'), findsOneWidget);
  });

  testWidgets('data 1. campo exibe Data da movimentação', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await tester.ensureVisible(find.byType(MovementDateField));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 15/08/2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Selecionar data da movimentação'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('data 2. explicação informa que não é vencimento', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    expect(find.text(movementDateExplanation), findsOneWidget);
    expect(find.text(futureMovementExplanation), findsOneWidget);
  });

  testWidgets('data 3. seletor abre na visualização diária', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    final CalendarDatePicker picker = tester.widget(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialCalendarMode, DatePickerMode.day);
    expect(find.byType(InputDatePickerFormField), findsNothing);
  });

  testWidgets('data 4. seletor abre no mês da data registrada', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      transaction: createTestTransaction(
        occurredAt: DateTime.utc(2025, 7, 10, 3),
      ),
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.editTransaction('transaction-1'));
    await _openMovementCalendar(tester);
    final CalendarDatePicker picker = tester.widget(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialDate, DateTime(2025, 7, 10));
  });

  testWidgets('data 5. novo lançamento inicia com hoje em São Paulo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    expect(find.text('Data da movimentação: 15/08/2026'), findsOneWidget);
  });

  testWidgets('data 6. permite escolher data anterior', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.text('14'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 14/08/2026'), findsOneWidget);
  });

  testWidgets('data 7. permite escolher outro mês anterior', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 10/07/2026'), findsOneWidget);
  });

  testWidgets('data 8. permite escolher outro ano anterior', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.textContaining('2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 12/08/2025'), findsOneWidget);
  });

  testWidgets('data 9. hoje é permitido', (WidgetTester tester) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    final CalendarDatePicker picker = tester.widget(
      find.byType(CalendarDatePicker),
    );
    expect(picker.currentDate, DateTime(2026, 8, 15));
    expect(picker.lastDate, DateTime(2026, 8, 15));
  });

  testWidgets('data 10. amanhã permanece desabilitado', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.text('16'), warnIfMissed: false);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 15/08/2026'), findsOneWidget);
  });

  test('data 11. qualquer data futura é bloqueada', () {
    expect(
      FinancialTransactionDate.isFutureDate(
        DateTime.utc(2030, 1, 1, 3),
        DateTime.utc(2026, 8, 15, 15),
      ),
      isTrue,
    );
  });

  testWidgets('data 12. cancelar calendário preserva a data anterior', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.text('14'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 15/08/2026'), findsOneWidget);
  });

  testWidgets('data 13. confirmar calendário atualiza a data', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    await tester.tap(find.text('13'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Data da movimentação: 13/08/2026'), findsOneWidget);
  });

  testWidgets('data 14. edição abre com a data já registrada', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpHarness(
      tester,
      transaction: createTestTransaction(
        occurredAt: DateTime.utc(2026, 7, 9, 3),
      ),
    );
    addTearDown(harness.dispose);
    await _go(tester, AppRoutes.editTransaction('transaction-1'));
    expect(find.text('Data da movimentação: 09/07/2026'), findsOneWidget);
    await _openMovementCalendar(tester);
    final CalendarDatePicker picker = tester.widget(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialDate, DateTime(2026, 7, 9));
  });

  testWidgets('data 15. mudar o mês recalcula o resumo', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    await harness.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Receita de julho',
        occurredAt: DateTime.utc(2026, 7, 31, 3),
        notes: '',
      ),
    );
    expect(harness.workspace.summary.currentMonth.income.cents, 0);
  });

  testWidgets('data 16. mudar o mês não altera o saldo atual', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openDetails(tester);
    addTearDown(harness.dispose);
    final int before = harness.workspace.summary.totalCurrentBalance.cents;
    await harness.action.updateTransaction(
      transactionId: 'transaction-1',
      edit: FinancialTransactionEdit(
        categoryId: 'category-1',
        description: 'Receita de julho',
        occurredAt: DateTime.utc(2026, 7, 31, 3),
        notes: '',
      ),
    );
    expect(harness.workspace.summary.totalCurrentBalance.cents, before);
  });

  test('data 17. UTC preserva o dia civil de São Paulo', () {
    expect(
      FinancialTransactionDate.saoPauloCalendarDate(
        DateTime.utc(2026, 8, 1, 2, 59, 59),
      ),
      DateTime.utc(2026, 7, 31),
    );
    expect(
      FinancialTransactionDate.saoPauloCalendarDate(
        DateTime.utc(2026, 8, 1, 3),
      ),
      DateTime.utc(2026, 8, 1),
    );
  });

  testWidgets('data 18. fonte ampliada não corta o campo', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await tester.ensureVisible(find.byType(MovementDateField));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data da movimentação:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data 19. tela pequena não gera overflow no campo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MovementDateField(
              selectedDate: DateTime(2026, 8, 15),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Data da movimentação:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data 20. temas claro e escuro mantêm o campo legível', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    expect(find.text(movementDateExplanation), findsOneWidget);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.onPlatformBrightnessChanged?.call();
    await tester.pumpAndSettle();
    expect(find.text(movementDateExplanation), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });

  testWidgets('data 21. botão físico fecha primeiro o calendário', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _openNew(tester);
    addTearDown(harness.dispose);
    await _openMovementCalendar(tester);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('Novo lançamento'), findsOneWidget);
  });

  test('data 22. modelo não contém campo de vencimento', () {
    expect(
      FirestoreFinancialTransactionMapper.fieldNames,
      isNot(contains('dueDate')),
    );
    expect(
      FirestoreFinancialTransactionMapper.fieldNames,
      isNot(contains('vencimento')),
    );
  });

  test('data 23. criação programática futura continua bloqueada', () {
    final FinancialTransactionDraft draft = FinancialTransactionDraft(
      accountId: 'account-1',
      categoryId: 'category-1',
      kind: FinancialTransactionKind.income,
      description: 'Receita futura inválida',
      amountCents: 100,
      occurredAt: DateTime.utc(2026, 8, 16, 3),
      notes: '',
    );
    expect(
      () => draft.normalized(now: DateTime.utc(2026, 8, 15, 15)),
      throwsA(
        isA<FinancialTransactionFailure>().having(
          (FinancialTransactionFailure failure) => failure.safeMessage,
          'mensagem segura',
          'Escolha uma data de hoje ou anterior.',
        ),
      ),
    );
  });
}

final class _Harness {
  const _Harness({
    required this.auth,
    required this.transactions,
    required this.container,
  });

  final FakeAuthRepository auth;
  final FakeFinancialTransactionRepository transactions;
  final ProviderContainer container;

  FinancialTransactionActionController get action =>
      container.read(financialTransactionActionControllerProvider.notifier);

  FinancialWorkspace get workspace =>
      container.read(financialWorkspaceProvider).requireValue;

  void dispose() => unawaited(auth.close());
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  FinancialTransaction? transaction,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialTransactionRepository transactions =
      FakeFinancialTransactionRepository(
        initialTransactions: <FinancialTransaction>[
          transaction ?? createTestTransaction(),
        ],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
        firebaseStartupProvider.overrideWithValue(
          const FirebaseStartupAvailable(),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        masterAccessSubjectProvider.overrideWithValue(null),
        userProfileRepositoryProvider.overrideWithValue(
          FakeUserProfileRepository(
            initialProfile: createTestProfile(ownerId: 'owner'),
          ),
        ),
        financialAccountRepositoryProvider.overrideWithValue(
          FakeFinancialAccountRepository(
            initialAccounts: <FinancialAccount>[createTestAccount()],
          ),
        ),
        financialCategoryRepositoryProvider.overrideWithValue(
          FakeFinancialCategoryRepository(
            initialCategories: <FinancialCategory>[
              createTestCategory(),
              createTestCategory(
                id: 'income-bonus',
                name: 'Bônus',
                icon: FinancialCategoryIcon.other,
              ),
              createTestCategory(
                id: 'expense-category',
                name: 'Alimentação',
                kind: FinancialCategoryKind.expense,
                icon: FinancialCategoryIcon.food,
                color: FinancialCategoryColor.orange,
              ),
            ],
          ),
        ),
        financialTransactionRepositoryProvider.overrideWithValue(transactions),
        financialClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 8, 15, 15),
        ),
      ],
      child: const MeuGestorFinanceiroApp(),
    ),
  );
  await tester.pumpAndSettle();
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  return _Harness(
    auth: auth,
    transactions: transactions,
    container: ProviderScope.containerOf(context),
  );
}

Future<_Harness> _openList(
  WidgetTester tester, {
  FinancialTransaction? transaction,
}) async {
  final _Harness harness = await _pumpHarness(tester, transaction: transaction);
  await tester.ensureVisible(find.text('Lançamentos'));
  await tester.tap(find.text('Lançamentos'));
  await tester.pumpAndSettle();
  return harness;
}

Future<_Harness> _openNew(WidgetTester tester) async {
  final _Harness harness = await _openList(tester);
  await tester.tap(find.text('Novo lançamento'));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _openMovementCalendar(WidgetTester tester) async {
  final Finder field = find.byType(MovementDateField);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: field, matching: find.byType(OutlinedButton)),
  );
  await tester.pumpAndSettle();
}

Future<_Harness> _openDetails(
  WidgetTester tester, {
  FinancialTransaction? transaction,
}) async {
  final _Harness harness = await _openList(tester, transaction: transaction);
  final String description =
      transaction?.description ?? createTestTransaction().description;
  await _revealTransaction(tester, description);
  await tester.tap(find.text(description));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _revealTransaction(WidgetTester tester, String description) async {
  await tester.scrollUntilVisible(
    find.text(description),
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<_Harness> _openEdit(WidgetTester tester) async {
  final _Harness harness = await _openDetails(tester);
  await tester.tap(find.text('Editar dados descritivos'));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _go(WidgetTester tester, String location) async {
  final BuildContext context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
}

Future<void> _confirmCancellation(WidgetTester tester) async {
  await tester.tap(find.text('Cancelar lançamento'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Cancelar lançamento'));
  await tester.pumpAndSettle();
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Finder _dropdown(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);
