import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_entitlement_diagnostics.dart';

void main() {
  test('development diagnostic is sanitized', () {
    final List<String> messages = <String>[];
    PremiumEntitlementDiagnostics(
      environment: AppEnvironment.development,
      writer: messages.add,
    ).record(
      operation: 'read_premium',
      stage: 'server',
      category: 'permissionDenied',
      error: StateError('sensitive synthetic detail'),
      firestoreCode: 'permission-denied',
    );
    expect(messages, hasLength(1));
    expect(messages.single, isNot(contains('sensitive synthetic detail')));
    expect(messages.single, isNot(contains('@')));
  });

  test('production emits no diagnostic', () {
    final List<String> messages = <String>[];
    PremiumEntitlementDiagnostics(
      environment: AppEnvironment.production,
      writer: messages.add,
    ).record(operation: 'read_premium', stage: 'server', category: 'unknown');
    expect(messages, isEmpty);
  });
}
