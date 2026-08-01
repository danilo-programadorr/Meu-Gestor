import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_diagnostics.dart';

void main() {
  test('development registra somente campos técnicos sanitizados', () {
    final List<String> messages = <String>[];
    final FinancialAccountDiagnostics diagnostics = FinancialAccountDiagnostics(
      environment: AppEnvironment.development,
      writer: messages.add,
    );
    diagnostics.record(
      operation: 'create_account',
      stage: 'server_confirmation',
      category: 'unavailable',
      error: StateError('nome e saldo que não podem entrar no log'),
      firestoreCode: 'unavailable',
    );
    expect(messages, hasLength(1));
    expect(messages.single, contains('operation=create_account'));
    expect(messages.single, contains('stage=server_confirmation'));
    expect(messages.single, contains('category=unavailable'));
    expect(messages.single, contains('firestoreCode=unavailable'));
    expect(messages.single, isNot(contains('nome e saldo')));
  });

  test('production não registra diagnóstico financeiro', () {
    final List<String> messages = <String>[];
    final FinancialAccountDiagnostics diagnostics = FinancialAccountDiagnostics(
      environment: AppEnvironment.production,
      writer: messages.add,
    );
    diagnostics.record(
      operation: 'read_accounts',
      stage: 'server_read',
      category: 'unknown',
      error: StateError('erro'),
    );
    expect(messages, isEmpty);
  });
}
