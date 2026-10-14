import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/home/domain/home_cash_flow_forecast.dart';

import '../../../support/financial_commitment_fixtures.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 15,
  );

  test('inclui obrigações vencidas e exclui recebimentos vencidos', () {
    final HomeCashFlowForecast forecast =
        HomeCashFlowForecastCalculator.calculate(
          openingBalance: const Money.fromCents(100000),
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'overdue-payable',
              amountCents: 20000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 10),
            ),
            createTestPayable(
              id: 'future-payable',
              amountCents: 30000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 20),
            ),
          ],
          receivables: <Receivable>[
            createTestReceivable(
              id: 'overdue-receivable',
              amountCents: 90000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 14),
            ),
            createTestReceivable(
              id: 'future-receivable',
              amountCents: 25000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 21),
            ),
          ],
        );

    expect(forecast.scheduledPayables.cents, 50000);
    expect(forecast.scheduledReceivables.cents, 25000);
    expect(forecast.projectedBalance.cents, 75000);
    expect(forecast.excludedOverdueReceivables.cents, 90000);
    expect(forecast.excludedOverdueReceivableCount, 1);
  });

  test('usa intervalo civil de trinta dias com fim exclusivo', () {
    final HomeCashFlowForecast forecast =
        HomeCashFlowForecastCalculator.calculate(
          openingBalance: const Money.fromCents(100000),
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'last-included',
              amountCents: 10000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 9, day: 13),
            ),
            createTestPayable(
              id: 'first-excluded',
              amountCents: 70000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 9, day: 14),
            ),
          ],
          receivables: const <Receivable>[],
        );

    expect(
      forecast.endExclusive,
      SaoPauloCivilDate(year: 2026, month: 9, day: 14),
    );
    expect(
      forecast.endInclusive,
      SaoPauloCivilDate(year: 2026, month: 9, day: 13),
    );
    expect(forecast.scheduledPayables.cents, 10000);
  });

  test('ignora compromissos liquidados, cancelados e anulados', () {
    final HomeCashFlowForecast forecast =
        HomeCashFlowForecastCalculator.calculate(
          openingBalance: const Money.fromCents(50000),
          today: today,
          payables: <Payable>[
            createTestPayable(status: PayableStatus.paid, amountCents: 10000),
            createTestPayable(
              id: 'cancelled',
              status: PayableStatus.cancelled,
              amountCents: 20000,
            ),
            createTestPayable(
              id: 'voided',
              status: PayableStatus.voided,
              amountCents: 30000,
            ),
          ],
          receivables: <Receivable>[
            createTestReceivable(
              status: ReceivableStatus.received,
              amountCents: 10000,
            ),
            createTestReceivable(
              id: 'cancelled-receivable',
              status: ReceivableStatus.cancelled,
              amountCents: 20000,
            ),
          ],
        );

    expect(forecast.scheduledPayables.cents, 0);
    expect(forecast.scheduledReceivables.cents, 0);
    expect(forecast.projectedBalance.cents, 50000);
  });

  test('identifica o primeiro fechamento diário com saldo negativo', () {
    final HomeCashFlowForecast forecast =
        HomeCashFlowForecastCalculator.calculate(
          openingBalance: const Money.fromCents(10000),
          today: today,
          payables: <Payable>[
            createTestPayable(
              id: 'first',
              amountCents: 8000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 16),
            ),
            createTestPayable(
              id: 'second',
              amountCents: 10000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 18),
            ),
          ],
          receivables: <Receivable>[
            createTestReceivable(
              amountCents: 5000,
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 17),
            ),
          ],
        );

    expect(
      forecast.firstNegativeDate,
      SaoPauloCivilDate(year: 2026, month: 8, day: 18),
    );
    expect(forecast.projectedBalance.cents, -3000);
  });

  test('saldo inicial negativo sinaliza o dia atual', () {
    final HomeCashFlowForecast forecast =
        HomeCashFlowForecastCalculator.calculate(
          openingBalance: const Money.fromCents(-1),
          payables: const <Payable>[],
          receivables: const <Receivable>[],
          today: today,
        );

    expect(forecast.firstNegativeDate, today);
  });
}
