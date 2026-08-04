import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';

enum DashboardPeriodPreset {
  currentMonth('Este mês'),
  previousMonth('Mês anterior'),
  currentYear('Este ano'),
  monthAndYear('Mês e ano'),
  custom('Período');

  const DashboardPeriodPreset(this.label);

  final String label;
}

final class HomeDashboardFilter {
  const HomeDashboardFilter({
    required this.period,
    required this.start,
    required this.end,
    this.accountId,
  });

  factory HomeDashboardFilter.currentMonth(SaoPauloCivilDate today) =>
      HomeDashboardFilter.forPreset(DashboardPeriodPreset.currentMonth, today);

  factory HomeDashboardFilter.forPreset(
    DashboardPeriodPreset preset,
    SaoPauloCivilDate today,
  ) {
    final ({SaoPauloCivilDate start, SaoPauloCivilDate end}) dates =
        switch (preset) {
          DashboardPeriodPreset.currentMonth => _monthRange(
            today.year,
            today.month,
          ),
          DashboardPeriodPreset.previousMonth =>
            today.month == 1
                ? _monthRange(today.year - 1, 12)
                : _monthRange(today.year, today.month - 1),
          DashboardPeriodPreset.currentYear => (
            start: SaoPauloCivilDate(year: today.year, month: 1, day: 1),
            end: SaoPauloCivilDate(year: today.year, month: 12, day: 31),
          ),
          DashboardPeriodPreset.monthAndYear => _monthRange(
            today.year,
            today.month,
          ),
          DashboardPeriodPreset.custom => _monthRange(today.year, today.month),
        };
    return HomeDashboardFilter(
      period: preset,
      start: dates.start,
      end: dates.end,
    );
  }

  factory HomeDashboardFilter.custom({
    required SaoPauloCivilDate start,
    required SaoPauloCivilDate end,
    String? accountId,
  }) {
    if (end.isBefore(start)) {
      throw ArgumentError('O fim do período deve ser posterior ao início.');
    }
    return HomeDashboardFilter(
      period: DashboardPeriodPreset.custom,
      start: start,
      end: end,
      accountId: accountId,
    );
  }

  factory HomeDashboardFilter.monthAndYear({
    required int year,
    required int month,
    String? accountId,
  }) {
    final ({SaoPauloCivilDate start, SaoPauloCivilDate end}) dates =
        _monthRange(year, month);
    return HomeDashboardFilter(
      period: DashboardPeriodPreset.monthAndYear,
      start: dates.start,
      end: dates.end,
      accountId: accountId,
    );
  }

  final DashboardPeriodPreset period;
  final SaoPauloCivilDate start;
  final SaoPauloCivilDate end;
  final String? accountId;

  String get periodLabel {
    if (period == DashboardPeriodPreset.monthAndYear) {
      final String value = DateFormat(
        'MMMM yyyy',
        'pt_BR',
      ).format(start.toUtcCalendarDate());
      return '${value[0].toUpperCase()}${value.substring(1)}';
    }
    if (period != DashboardPeriodPreset.custom) {
      return period.label;
    }
    final DateFormat formatter = DateFormat('dd/MM/yy', 'pt_BR');
    return '${formatter.format(start.toUtcCalendarDate())} – '
        '${formatter.format(end.toUtcCalendarDate())}';
  }

  bool includes(SaoPauloCivilDate date) =>
      !date.isBefore(start) && !date.isAfter(end);

  bool isDefaultFor(SaoPauloCivilDate today) {
    final HomeDashboardFilter initial = HomeDashboardFilter.currentMonth(today);
    return accountId == null &&
        period == DashboardPeriodPreset.currentMonth &&
        start == initial.start &&
        end == initial.end;
  }

  HomeDashboardFilter withAccount(String? value) => HomeDashboardFilter(
    period: period,
    start: start,
    end: end,
    accountId: value,
  );

  HomeDashboardFilter withPreset(
    DashboardPeriodPreset value,
    SaoPauloCivilDate today,
  ) {
    final HomeDashboardFilter replacement = HomeDashboardFilter.forPreset(
      value,
      today,
    );
    return replacement.withAccount(accountId);
  }

  static ({SaoPauloCivilDate start, SaoPauloCivilDate end}) _monthRange(
    int year,
    int month,
  ) {
    final int lastDay = DateTime.utc(year, month + 1, 0).day;
    return (
      start: SaoPauloCivilDate(year: year, month: month, day: 1),
      end: SaoPauloCivilDate(year: year, month: month, day: lastDay),
    );
  }
}
