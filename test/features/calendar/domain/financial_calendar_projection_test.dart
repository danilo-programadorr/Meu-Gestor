import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_projection.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import '../../../support/financial_commitment_fixtures.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 10,
  );

  FinancialCalendarRecurrence recurrence({
    FinancialCalendarRecurrenceFrequency frequency =
        FinancialCalendarRecurrenceFrequency.monthly,
    SaoPauloCivilDate? anchorDate,
    SaoPauloCivilDate? endsOn,
  }) => FinancialCalendarRecurrence(
    id: 'recurrence-1',
    sourceKind: FinancialCommitmentKind.payable,
    sourceCommitmentId: 'payable-1',
    frequency: frequency,
    interval: 1,
    anchorDate: anchorDate ?? SaoPauloCivilDate(year: 2026, month: 8, day: 31),
    endsOn: endsOn,
    isActive: true,
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
    cancelledAt: null,
  );

  test('deriva atraso sem persistir o estado e preserva data de movimento', () {
    final FinancialCalendarProjection projection =
        FinancialCalendarProjector.project(
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'payable-1',
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 9),
            ),
            createTestPayable(
              id: 'payable-paid',
              status: PayableStatus.paid,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 2),
              paidDate: SaoPauloCivilDate(year: 2026, month: 8, day: 7),
            ),
          ],
          receivables: const <Receivable>[],
          recurrences: const <FinancialCalendarRecurrence>[],
          horizonEnd: SaoPauloCivilDate(year: 2026, month: 9, day: 10),
        );

    expect(projection.entries[0].status, FinancialCalendarEntryStatus.paid);
    expect(
      projection.entries[0].movementDate,
      SaoPauloCivilDate(year: 2026, month: 8, day: 7),
    );
    expect(projection.entries[1].status, FinancialCalendarEntryStatus.overdue);
    expect(projection.entries[1].movementDate, isNull);
  });

  test('projeta recorrência mensal no último dia quando o dia não existe', () {
    final FinancialCalendarProjection projection =
        FinancialCalendarProjector.project(
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'payable-1',
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 31),
            ),
          ],
          receivables: const <Receivable>[],
          recurrences: <FinancialCalendarRecurrence>[recurrence()],
          horizonEnd: SaoPauloCivilDate(year: 2026, month: 11, day: 1),
        );

    final List<FinancialCalendarEntry> forecast = projection.entries
        .where((FinancialCalendarEntry entry) => entry.isForecast)
        .toList(growable: false);
    expect(
      forecast.map((FinancialCalendarEntry entry) => entry.dueDate),
      <SaoPauloCivilDate>[
        SaoPauloCivilDate(year: 2026, month: 9, day: 30),
        SaoPauloCivilDate(year: 2026, month: 10, day: 31),
      ],
    );
    expect(
      forecast.every(
        (FinancialCalendarEntry entry) => !entry.affectsRealBalance,
      ),
      isTrue,
    );
  });

  test('previsão separa entradas, saídas e não conta liquidações', () {
    final FinancialCalendarProjection projection =
        FinancialCalendarProjector.project(
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'payable-1',
              amountCents: 2500,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 15),
            ),
          ],
          receivables: <Receivable>[
            createTestReceivable(
              id: 'receivable-1',
              amountCents: 5000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 20),
            ),
            createTestReceivable(
              id: 'receivable-paid',
              amountCents: 9000,
              status: ReceivableStatus.received,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 11),
              receivedDate: SaoPauloCivilDate(year: 2026, month: 8, day: 10),
            ),
          ],
          recurrences: const <FinancialCalendarRecurrence>[],
          horizonEnd: SaoPauloCivilDate(year: 2026, month: 8, day: 31),
        );

    final FinancialCalendarForecast forecast = projection.forecastUntil(
      SaoPauloCivilDate(year: 2026, month: 8, day: 31),
    );
    expect(forecast.incomingCents, 5000);
    expect(forecast.outgoingCents, 2500);
    expect(forecast.netCents, 2500);
    expect(forecast.entryCount, 2);
  });

  test('fonte de recorrência ausente não gera previsão', () {
    final FinancialCalendarProjection projection =
        FinancialCalendarProjector.project(
          today: today,
          payables: const <Payable>[],
          receivables: const <Receivable>[],
          recurrences: <FinancialCalendarRecurrence>[recurrence()],
          horizonEnd: SaoPauloCivilDate(year: 2026, month: 9, day: 30),
        );

    expect(projection.entries, isEmpty);
    expect(projection.missingRecurrenceSourceIds, <String>{'payable-1'});
  });
}
