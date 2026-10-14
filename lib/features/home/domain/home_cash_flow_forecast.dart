import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';

final class HomeCashFlowForecast {
  const HomeCashFlowForecast({
    required this.start,
    required this.endExclusive,
    required this.openingBalance,
    required this.scheduledPayables,
    required this.scheduledReceivables,
    required this.projectedBalance,
    required this.excludedOverdueReceivables,
    required this.excludedOverdueReceivableCount,
    required this.firstNegativeDate,
  });

  final SaoPauloCivilDate start;
  final SaoPauloCivilDate endExclusive;
  final Money openingBalance;
  final Money scheduledPayables;
  final Money scheduledReceivables;
  final Money projectedBalance;
  final Money excludedOverdueReceivables;
  final int excludedOverdueReceivableCount;
  final SaoPauloCivilDate? firstNegativeDate;

  SaoPauloCivilDate get endInclusive => _addDays(endExclusive, -1);
}

abstract final class HomeCashFlowForecastCalculator {
  static const int defaultHorizonDays = 30;

  static HomeCashFlowForecast calculate({
    required Money openingBalance,
    required List<Payable> payables,
    required List<Receivable> receivables,
    required SaoPauloCivilDate today,
    int horizonDays = defaultHorizonDays,
  }) {
    if (horizonDays < 1 || horizonDays > 366) {
      throw ArgumentError.value(
        horizonDays,
        'horizonDays',
        'O horizonte deve ter entre 1 e 366 dias.',
      );
    }
    final SaoPauloCivilDate endExclusive = _addDays(today, horizonDays);
    final Map<SaoPauloCivilDate, int> dailyDeltaCents =
        <SaoPauloCivilDate, int>{};
    int payableCents = 0;
    int receivableCents = 0;
    int excludedOverdueReceivableCents = 0;
    int excludedOverdueReceivableCount = 0;

    for (final Payable payable in payables) {
      if (!payable.isPending || !payable.dueDate.isBefore(endExclusive)) {
        continue;
      }
      payableCents += payable.amountCents;
      final SaoPauloCivilDate effectiveDate = payable.dueDate.isBefore(today)
          ? today
          : payable.dueDate;
      dailyDeltaCents.update(
        effectiveDate,
        (int current) => current - payable.amountCents,
        ifAbsent: () => -payable.amountCents,
      );
    }

    for (final Receivable receivable in receivables) {
      if (!receivable.isPending) continue;
      if (receivable.dueDate.isBefore(today)) {
        excludedOverdueReceivableCents += receivable.amountCents;
        excludedOverdueReceivableCount += 1;
        continue;
      }
      if (!receivable.dueDate.isBefore(endExclusive)) continue;
      receivableCents += receivable.amountCents;
      dailyDeltaCents.update(
        receivable.dueDate,
        (int current) => current + receivable.amountCents,
        ifAbsent: () => receivable.amountCents,
      );
    }

    int runningBalanceCents = openingBalance.cents;
    SaoPauloCivilDate? firstNegativeDate = runningBalanceCents < 0
        ? today
        : null;
    final List<SaoPauloCivilDate> eventDates = dailyDeltaCents.keys.toList()
      ..sort();
    for (final SaoPauloCivilDate date in eventDates) {
      runningBalanceCents += dailyDeltaCents[date]!;
      if (firstNegativeDate == null && runningBalanceCents < 0) {
        firstNegativeDate = date;
      }
    }

    return HomeCashFlowForecast(
      start: today,
      endExclusive: endExclusive,
      openingBalance: openingBalance,
      scheduledPayables: Money.fromCents(payableCents),
      scheduledReceivables: Money.fromCents(receivableCents),
      projectedBalance: Money.fromCents(runningBalanceCents),
      excludedOverdueReceivables: Money.fromCents(
        excludedOverdueReceivableCents,
      ),
      excludedOverdueReceivableCount: excludedOverdueReceivableCount,
      firstNegativeDate: firstNegativeDate,
    );
  }
}

SaoPauloCivilDate _addDays(SaoPauloCivilDate date, int days) =>
    SaoPauloCivilDate.fromCalendarDate(
      date.toUtcCalendarDate().add(Duration(days: days)),
    );
