import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';

void main() {
  group('AssistantContextCatalog', () {
    test('classifica todas as fontes sem simular módulos futuros', () {
      expect(
        AssistantContextCatalog.policies.map((policy) => policy.source).toSet(),
        AssistantContextSource.values.toSet(),
      );
      expect(
        AssistantContextCatalog.policies
            .where(
              (policy) =>
                  policy.availability ==
                  AssistantContextAvailability.futureUnavailable,
            )
            .map((policy) => policy.source),
        containsAll(<AssistantContextSource>{
          AssistantContextSource.debtsAndInterest,
          AssistantContextSource.budgets,
          AssistantContextSource.goalsAndEmergencyReserve,
          AssistantContextSource.projectedBalance,
          AssistantContextSource.historicalTrends,
        }),
      );
    });

    test('bloqueia identificadores e segredos na fronteira do provedor', () {
      expect(AssistantContextCatalog.forbiddenProviderFields, contains('uid'));
      expect(
        AssistantContextCatalog.forbiddenProviderFields,
        containsAll(<String>{'email', 'token', 'apiKey', 'projectId'}),
      );
    });
  });

  group('AssistantFinancialContext', () {
    test('aceita somente fatos tipados e confirmados pelo servidor', () {
      final DateTime now = DateTime.utc(2026, 8, 24, 12);
      final AssistantFinancialContext context = AssistantFinancialContext(
        generatedAt: now,
        periodStart: DateTime.utc(2026, 8, 1, 3),
        periodEnd: now,
        facts: <AssistantContextFact>[
          AssistantContextFact(
            evidenceId: 'monthly_income',
            source: AssistantContextSource.transactions,
            kind: AssistantFactKind.moneyCentsBrl,
            value: 250000,
          ),
        ],
        missingSources: const <AssistantContextSource>{
          AssistantContextSource.budgets,
        },
        isFromServer: true,
        hasPendingWrites: false,
      );

      expect(context.facts.single.value, 250000);
      expect(context.missingSources, contains(AssistantContextSource.budgets));
    });

    test('recusa ponto flutuante, cache, duplicidade e texto sensível', () {
      expect(
        () => AssistantContextFact(
          evidenceId: 'balance_value',
          source: AssistantContextSource.accounts,
          kind: AssistantFactKind.moneyCentsBrl,
          value: 1.5,
        ),
        throwsA(isA<AssistantFailure>()),
      );
      expect(
        () => AssistantContextFact(
          evidenceId: 'unsafe_label',
          source: AssistantContextSource.categories,
          kind: AssistantFactKind.safeLabel,
          value: 'terceiro@exemplo.com',
        ),
        throwsA(isA<AssistantFailure>()),
      );

      final AssistantContextFact fact = AssistantContextFact(
        evidenceId: 'account_balance',
        source: AssistantContextSource.accounts,
        kind: AssistantFactKind.moneyCentsBrl,
        value: 100,
      );
      expect(
        () => AssistantFinancialContext(
          generatedAt: DateTime.utc(2026, 8, 24),
          periodStart: DateTime.utc(2026, 8, 1),
          periodEnd: DateTime.utc(2026, 8, 24),
          facts: <AssistantContextFact>[fact, fact],
          missingSources: const <AssistantContextSource>{},
          isFromServer: false,
          hasPendingWrites: true,
        ),
        throwsA(isA<AssistantFailure>()),
      );
    });
  });
}
