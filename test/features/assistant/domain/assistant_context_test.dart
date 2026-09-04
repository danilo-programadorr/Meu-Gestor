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

    test('inclui calendário financeiro próprio sem agenda externa', () {
      final AssistantContextSourcePolicy calendarPolicy =
          AssistantContextCatalog.policies.singleWhere(
            (AssistantContextSourcePolicy policy) =>
                policy.source == AssistantContextSource.financialCalendar,
          );

      expect(
        calendarPolicy.availability,
        AssistantContextAvailability.available,
      );
      expect(calendarPolicy.containsOwnData, isTrue);
    });
  });

  group('AssistantFinancialContext', () {
    test('aceita somente fatos tipados e confirmados pelo servidor', () {
      final DateTime now = DateTime.utc(2026, 8, 24, 12);
      final AssistantCivilPeriod period = AssistantCivilPeriod(
        startDate: '2026-08-01',
        endDateExclusive: '2026-08-25',
      );
      final AssistantFinancialContext context = AssistantFinancialContext(
        generatedAt: now,
        civilPeriod: period,
        technicalWindowStart: DateTime.utc(2026, 8, 1, 3),
        technicalWindowEndExclusive: now,
        facts: <AssistantContextFact>[
          AssistantContextFact(
            evidenceId: 'monthly_income',
            source: AssistantContextSource.transactions,
            kind: AssistantFactKind.moneyCentsBrl,
            value: 250000,
            civilPeriod: period,
            evidence: AssistantFactEvidence(
              alias: 'monthly_income',
              source: AssistantContextSource.transactions,
              period: period,
            ),
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

    test('período civil exige São Paulo e fim exclusivo posterior', () {
      expect(
        () => AssistantCivilPeriod(
          timeZone: 'UTC',
          startDate: '2026-10-17',
          endDateExclusive: '2026-10-18',
        ),
        throwsA(isA<AssistantFailure>()),
      );
      expect(
        () => AssistantCivilPeriod(
          startDate: '2026-02-29',
          endDateExclusive: '2026-02-29',
        ),
        throwsA(isA<AssistantFailure>()),
      );
    });

    test('recusa ponto flutuante, cache, duplicidade e texto sensível', () {
      expect(
        () => AssistantContextFact(
          evidenceId: 'balance_value',
          source: AssistantContextSource.accounts,
          kind: AssistantFactKind.moneyCentsBrl,
          value: 1.5,
          civilPeriod: AssistantCivilPeriod(
            startDate: '2026-08-01',
            endDateExclusive: '2026-08-02',
          ),
          evidence: AssistantFactEvidence(
            alias: 'balance_value',
            source: AssistantContextSource.accounts,
            period: AssistantCivilPeriod(
              startDate: '2026-08-01',
              endDateExclusive: '2026-08-02',
            ),
          ),
        ),
        throwsA(isA<AssistantFailure>()),
      );
      expect(
        () => AssistantContextFact(
          evidenceId: 'unsafe_label',
          source: AssistantContextSource.categories,
          kind: AssistantFactKind.safeLabel,
          value: 'terceiro@exemplo.com',
          civilPeriod: AssistantCivilPeriod(
            startDate: '2026-08-01',
            endDateExclusive: '2026-08-02',
          ),
          evidence: AssistantFactEvidence(
            alias: 'unsafe_label',
            source: AssistantContextSource.categories,
            period: AssistantCivilPeriod(
              startDate: '2026-08-01',
              endDateExclusive: '2026-08-02',
            ),
          ),
        ),
        throwsA(isA<AssistantFailure>()),
      );

      final AssistantContextFact fact = AssistantContextFact(
        evidenceId: 'account_balance',
        source: AssistantContextSource.accounts,
        kind: AssistantFactKind.moneyCentsBrl,
        value: 100,
        civilPeriod: AssistantCivilPeriod(
          startDate: '2026-08-01',
          endDateExclusive: '2026-08-02',
        ),
        evidence: AssistantFactEvidence(
          alias: 'account_balance',
          source: AssistantContextSource.accounts,
          period: AssistantCivilPeriod(
            startDate: '2026-08-01',
            endDateExclusive: '2026-08-02',
          ),
        ),
      );
      expect(
        () => AssistantFinancialContext(
          generatedAt: DateTime.utc(2026, 8, 24),
          civilPeriod: AssistantCivilPeriod(
            startDate: '2026-08-01',
            endDateExclusive: '2026-08-25',
          ),
          technicalWindowStart: DateTime.utc(2026, 8, 1),
          technicalWindowEndExclusive: DateTime.utc(2026, 8, 24),
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
