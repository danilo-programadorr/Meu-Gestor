import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/android_calendar_contract.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_projection.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/calendar/presentation/controllers/android_calendar_selection_controller.dart';
import 'package:meu_gestor_financeiro/features/calendar/presentation/controllers/financial_calendar_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/widgets/commitment_view_support.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

class FinancialCalendarPage extends ConsumerStatefulWidget {
  const FinancialCalendarPage({super.key});

  @override
  ConsumerState<FinancialCalendarPage> createState() =>
      _FinancialCalendarPageState();
}

class _FinancialCalendarPageState extends ConsumerState<FinancialCalendarPage> {
  SaoPauloCivilDate? _selectedDate;
  SaoPauloCivilDate? _visibleMonth;

  @override
  Widget build(BuildContext context) {
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(
      ref.watch(financialClockProvider)().toUtc(),
    );
    final SaoPauloCivilDate visibleMonth = _visibleMonth ??= SaoPauloCivilDate(
      year: today.year,
      month: today.month,
      day: 1,
    );
    final SaoPauloCivilDate selectedDate = _selectedDate ??= today;
    final AsyncValue<FinancialCommitmentsState<Payable>> payables = ref.watch(
      payablesControllerProvider,
    );
    final AsyncValue<FinancialCommitmentsState<Receivable>> receivables = ref
        .watch(receivablesControllerProvider);
    final AsyncValue<List<FinancialCalendarRecurrence>> recurrences = ref.watch(
      calendarRecurrencesControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário financeiro'),
        actions: <Widget>[
          IconButton(
            tooltip: valuesVisible ? 'Ocultar valores' : 'Mostrar valores',
            onPressed: () =>
                ref.read(financialPrivacyControllerProvider.notifier).toggle(),
            icon: Icon(
              valuesVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
      body: _body(
        context: context,
        valuesVisible: valuesVisible,
        today: today,
        visibleMonth: visibleMonth,
        selectedDate: selectedDate,
        payables: payables,
        receivables: receivables,
        recurrences: recurrences,
      ),
    );
  }

  Widget _body({
    required BuildContext context,
    required bool valuesVisible,
    required SaoPauloCivilDate today,
    required SaoPauloCivilDate visibleMonth,
    required SaoPauloCivilDate selectedDate,
    required AsyncValue<FinancialCommitmentsState<Payable>> payables,
    required AsyncValue<FinancialCommitmentsState<Receivable>> receivables,
    required AsyncValue<List<FinancialCalendarRecurrence>> recurrences,
  }) {
    if (payables.isLoading || receivables.isLoading || recurrences.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (payables.hasError || receivables.hasError || recurrences.hasError) {
      return _CalendarLoadFailure(
        onRetry: () async {
          await Future.wait<void>(<Future<void>>[
            ref.read(payablesControllerProvider.notifier).refresh(),
            ref.read(receivablesControllerProvider.notifier).refresh(),
            ref.read(calendarRecurrencesControllerProvider.notifier).refresh(),
          ]);
        },
      );
    }
    final FinancialCommitmentsState<Payable>? payableState = payables.value;
    final FinancialCommitmentsState<Receivable>? receivableState =
        receivables.value;
    final List<FinancialCalendarRecurrence>? recurrenceValues =
        recurrences.value;
    if (payableState == null ||
        receivableState == null ||
        recurrenceValues == null ||
        !payableState.isServerConfirmed ||
        !receivableState.isServerConfirmed) {
      return const _CalendarLoadFailure();
    }
    final SaoPauloCivilDate horizonEnd = _addMonths(visibleMonth, 6);
    final FinancialCalendarProjection projection =
        FinancialCalendarProjector.project(
          today: today,
          payables: payableState.commitments,
          receivables: receivableState.commitments,
          recurrences: recurrenceValues,
          horizonEnd: horizonEnd,
        );
    final SaoPauloCivilDate monthEnd = _monthEnd(visibleMonth);
    final FinancialCalendarForecast forecast = projection.forecastUntil(
      monthEnd,
    );
    final List<FinancialCalendarEntry> selectedEntries = projection.entriesOn(
      selectedDate,
    );
    final List<FinancialCommitment> templates =
        <FinancialCommitment>[
          ...payableState.commitments,
          ...receivableState.commitments,
        ]..sort(
          (FinancialCommitment first, FinancialCommitment second) =>
              first.description.compareTo(second.description),
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double horizontal = constraints.maxWidth <= 360
            ? AppSpacing.compactPageHorizontal
            : AppSpacing.pageHorizontal;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _CalendarIntro(),
                    const SizedBox(height: AppSpacing.md),
                    _ForecastCard(
                      forecast: forecast,
                      valuesVisible: valuesVisible,
                      month: visibleMonth,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MonthNavigator(
                      month: visibleMonth,
                      onPrevious: () => setState(
                        () => _visibleMonth = _addMonths(visibleMonth, -1),
                      ),
                      onNext: () => setState(
                        () => _visibleMonth = _addMonths(visibleMonth, 1),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CalendarMonthGrid(
                      month: visibleMonth,
                      selectedDate: selectedDate,
                      today: today,
                      entries: projection.entries,
                      onSelected: (SaoPauloCivilDate value) {
                        setState(() => _selectedDate = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SelectedDayCard(
                      date: selectedDate,
                      entries: selectedEntries,
                      valuesVisible: valuesVisible,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _UpcomingCard(
                      entries: projection.upcoming
                          .take(5)
                          .toList(growable: false),
                      valuesVisible: valuesVisible,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RecurrencesCard(
                      recurrences: recurrenceValues,
                      templates: templates,
                      onCreate: () => _showCreateRecurrence(templates),
                      onCancel: _confirmCancelRecurrence,
                    ),
                    if (projection
                        .missingRecurrenceSourceIds
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      const _MissingTemplateNotice(),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    const _AndroidCalendarCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _AssistantCalendarNotice(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateRecurrence(
    List<FinancialCommitment> templates,
  ) async {
    if (templates.isEmpty) {
      _showMessage(
        'Cadastre uma conta a pagar ou receber antes de planejar recorrência.',
      );
      return;
    }
    final FinancialCalendarRecurrenceDraft? draft =
        await showDialog<FinancialCalendarRecurrenceDraft>(
          context: context,
          builder: (BuildContext context) =>
              _CreateRecurrenceDialog(templates: templates),
        );
    if (!mounted || draft == null) return;
    final bool saved = await ref
        .read(calendarRecurrencesControllerProvider.notifier)
        .create(draft);
    if (!mounted) return;
    _showMessage(
      saved
          ? 'Previsão recorrente salva neste dispositivo.'
          : 'Não foi possível salvar a previsão recorrente. Tente novamente.',
    );
  }

  Future<void> _confirmCancelRecurrence(
    FinancialCalendarRecurrence recurrence,
  ) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar previsão recorrente?'),
        content: const Text(
          'As ocorrências futuras deixarão de aparecer. O histórico do plano e os compromissos financeiros serão preservados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar previsão'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    final bool cancelled = await ref
        .read(calendarRecurrencesControllerProvider.notifier)
        .cancel(recurrence.id);
    if (!mounted) return;
    _showMessage(
      cancelled
          ? 'Previsão recorrente cancelada; nenhum dado financeiro foi apagado.'
          : 'Não foi possível cancelar a previsão. Tente novamente.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CalendarIntro extends StatelessWidget {
  const _CalendarIntro();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_month_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sua agenda financeira',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Vencimentos, recebimentos e previsões recorrentes. Previsão não é lançamento e não altera seu saldo.',
          ),
        ],
      ),
    ),
  );
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.forecast,
    required this.valuesVisible,
    required this.month,
  });

  final FinancialCalendarForecast forecast;
  final bool valuesVisible;
  final SaoPauloCivilDate month;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Previsão do mês',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${_monthLabel(month)} • ${forecast.entryCount} compromisso(s) pendente(s) ou previsto(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ForecastValue(
            label: 'Entradas previstas',
            cents: forecast.incomingCents,
            valuesVisible: valuesVisible,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ForecastValue(
            label: 'Saídas previstas',
            cents: forecast.outgoingCents,
            valuesVisible: valuesVisible,
            color: Theme.of(context).colorScheme.error,
          ),
          const Divider(height: AppSpacing.lg),
          _ForecastValue(
            label: 'Resultado previsto',
            cents: forecast.netCents,
            valuesVisible: valuesVisible,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'É uma visão de vencimentos; pagamentos e recebimentos só entram no saldo após a movimentação real confirmada.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ForecastValue extends StatelessWidget {
  const _ForecastValue({
    required this.label,
    required this.cents,
    required this.valuesVisible,
    required this.color,
  });

  final String label;
  final int cents;
  final bool valuesVisible;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String value = valuesVisible
        ? MoneyFormatter.format(Money.fromCents(cents))
        : 'Valor oculto';
    return Semantics(
      label: '$label: $value',
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final SaoPauloCivilDate month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      IconButton(
        tooltip: 'Mês anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          _monthLabel(month),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      IconButton(
        tooltip: 'Próximo mês',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.entries,
    required this.onSelected,
  });

  final SaoPauloCivilDate month;
  final SaoPauloCivilDate selectedDate;
  final SaoPauloCivilDate today;
  final List<FinancialCalendarEntry> entries;
  final ValueChanged<SaoPauloCivilDate> onSelected;

  @override
  Widget build(BuildContext context) {
    final Map<SaoPauloCivilDate, List<FinancialCalendarEntry>> byDate =
        <SaoPauloCivilDate, List<FinancialCalendarEntry>>{};
    for (final FinancialCalendarEntry entry in entries) {
      if (entry.dueDate.year == month.year &&
          entry.dueDate.month == month.month) {
        (byDate[entry.dueDate] ??= <FinancialCalendarEntry>[]).add(entry);
      }
    }
    final int leading = month.toUtcCalendarDate().weekday - 1;
    final int days = _monthEnd(month).day;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                _WeekdayLabel('S'),
                _WeekdayLabel('T'),
                _WeekdayLabel('Q'),
                _WeekdayLabel('Q'),
                _WeekdayLabel('S'),
                _WeekdayLabel('S'),
                _WeekdayLabel('D'),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.88,
              ),
              itemCount: leading + days,
              itemBuilder: (BuildContext context, int index) {
                if (index < leading) return const SizedBox.shrink();
                final SaoPauloCivilDate date = SaoPauloCivilDate(
                  year: month.year,
                  month: month.month,
                  day: index - leading + 1,
                );
                final List<FinancialCalendarEntry> dayEntries =
                    byDate[date] ?? const <FinancialCalendarEntry>[];
                return _CalendarDayCell(
                  date: date,
                  selected: date == selectedDate,
                  isToday: date == today,
                  entries: dayEntries,
                  onTap: () => onSelected(date),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      excludeSemantics: true,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.entries,
    required this.onTap,
  });

  final SaoPauloCivilDate date;
  final bool selected;
  final bool isToday;
  final List<FinancialCalendarEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool hasOverdue = entries.any(
      (FinancialCalendarEntry entry) =>
          entry.status == FinancialCalendarEntryStatus.overdue,
    );
    final bool hasIncoming = entries.any(
      (FinancialCalendarEntry entry) => entry.isIncoming,
    );
    final bool hasOutgoing = entries.any(
      (FinancialCalendarEntry entry) => !entry.isIncoming,
    );
    final String status = entries.isEmpty
        ? 'sem compromissos'
        : '${entries.length} compromisso(s), ${hasOverdue ? 'com atraso' : 'sem atraso'}';
    return Semantics(
      button: true,
      selected: selected,
      label: '${formatCivilDate(date)}: $status',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer
                : isToday
                ? colors.surfaceContainerHigh
                : null,
            border: isToday ? Border.all(color: colors.primary) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (entries.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Wrap(
                  spacing: 2,
                  children: <Widget>[
                    if (hasIncoming)
                      _CalendarDot(color: colors.primary, label: 'Entrada'),
                    if (hasOutgoing)
                      _CalendarDot(
                        color: hasOverdue ? colors.error : colors.tertiary,
                        label: hasOverdue ? 'Atrasado' : 'Saída',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(width: 6, height: 6),
    ),
  );
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    required this.entries,
    required this.valuesVisible,
  });

  final SaoPauloCivilDate date;
  final List<FinancialCalendarEntry> entries;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Compromissos em ${formatCivilDate(date)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            const Text('Nenhum compromisso ou previsão nesta data.')
          else
            for (final FinancialCalendarEntry entry in entries)
              _CalendarEntryTile(entry: entry, valuesVisible: valuesVisible),
        ],
      ),
    ),
  );
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.entries, required this.valuesVisible});

  final List<FinancialCalendarEntry> entries;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Próximos compromissos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            const Text('Não há pendências ou previsões futuras confirmadas.')
          else
            for (final FinancialCalendarEntry entry in entries)
              _CalendarEntryTile(entry: entry, valuesVisible: valuesVisible),
        ],
      ),
    ),
  );
}

class _CalendarEntryTile extends StatelessWidget {
  const _CalendarEntryTile({required this.entry, required this.valuesVisible});

  final FinancialCalendarEntry entry;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final Color color = _entryColor(context, entry.status);
    final String amount = valuesVisible
        ? MoneyFormatter.format(Money.fromCents(entry.amountCents))
        : 'Valor oculto';
    return Semantics(
      label:
          '${entry.description}, $amount, vencimento ${formatCivilDate(entry.dueDate)}, ${entry.status.label}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    entry.isIncoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      entry.description,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(amount, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text('Vencimento: ${formatCivilDate(entry.dueDate)}'),
              if (entry.movementDate != null)
                Text(
                  'Movimentação real: ${formatCivilDate(entry.movementDate!)}',
                ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.status.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              if (entry.isForecast)
                const Text(
                  'Somente previsão recorrente — não cria pendência, lançamento ou saldo.',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrencesCard extends StatelessWidget {
  const _RecurrencesCard({
    required this.recurrences,
    required this.templates,
    required this.onCreate,
    required this.onCancel,
  });

  final List<FinancialCalendarRecurrence> recurrences;
  final List<FinancialCommitment> templates;
  final VoidCallback onCreate;
  final ValueChanged<FinancialCalendarRecurrence> onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.repeat_rounded),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Recorrências locais',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Adicionar previsão recorrente',
                onPressed: templates.isEmpty ? null : onCreate,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Usam um compromisso existente como modelo. Ficam neste dispositivo e não criam movimentações automaticamente.',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recurrences.isEmpty)
            const Text('Nenhuma previsão recorrente criada neste dispositivo.')
          else
            for (final FinancialCalendarRecurrence recurrence in recurrences)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  recurrence.isActive
                      ? Icons.repeat_rounded
                      : Icons.event_busy_outlined,
                ),
                title: Text(recurrence.frequency.label),
                subtitle: Text(
                  recurrence.isActive
                      ? 'A cada ${recurrence.interval} • início ${formatCivilDate(recurrence.anchorDate)}'
                      : 'Cancelada; histórico preservado',
                ),
                trailing: recurrence.isActive
                    ? IconButton(
                        tooltip: 'Cancelar previsão recorrente',
                        onPressed: () => onCancel(recurrence),
                        icon: const Icon(Icons.cancel_outlined),
                      )
                    : null,
              ),
        ],
      ),
    ),
  );
}

class _AndroidCalendarCard extends ConsumerWidget {
  const _AndroidCalendarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Set<String>> selection = ref.watch(
      androidCalendarSelectionControllerProvider,
    );
    final Set<String> selected = selection.value ?? const <String>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.event_outlined),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Calendário do Android',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Opcional. Nenhuma agenda é lida até você escolher explicitamente os calendários permitidos. Esta versão não cria, altera ou exclui eventos externos.',
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: selection.isLoading
                  ? null
                  : () => _configure(context, ref, selected),
              icon: const Icon(Icons.tune_outlined),
              label: Text(
                selected.isEmpty
                    ? 'Escolher calendários permitidos'
                    : '${selected.length} calendário(s) permitido(s)',
              ),
            ),
            if (selected.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton.icon(
                onPressed: () => _readAuthorizedEvents(context, ref, selected),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver próximos eventos permitidos'),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'A alteração da seleção não modifica eventos. Escritas externas continuam indisponíveis neste incremento.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configure(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) async {
    final List<AuthorizedAndroidCalendar> calendars;
    try {
      calendars = await ref
          .read(androidCalendarGatewayProvider)
          .listCalendars();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível acessar os calendários do aparelho. Nenhum evento foi lido.',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final Set<String>? next = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext context) => _AndroidCalendarSelectionDialog(
        calendars: calendars,
        selectedIds: selected,
      ),
    );
    if (!context.mounted || next == null) return;
    final bool saved = await ref
        .read(androidCalendarSelectionControllerProvider.notifier)
        .save(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Calendários permitidos atualizados. Nenhum evento foi alterado.'
              : 'Não foi possível salvar a seleção de calendários.',
        ),
      ),
    );
  }

  Future<void> _readAuthorizedEvents(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) async {
    final DateTime startsAt = DateTime.now().toUtc();
    final DateTime endsAt = startsAt.add(const Duration(days: 30));
    final List<AndroidCalendarEventPreview> events;
    try {
      events = await ref
          .read(androidCalendarGatewayProvider)
          .readAuthorizedEvents(
            authorizedCalendarIds: selected,
            startsAt: startsAt,
            endsAt: endsAt,
          );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ler os eventos permitidos. Nenhum evento foi salvo.',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _AndroidCalendarEventsDialog(events: events),
    );
  }
}

class _AndroidCalendarEventsDialog extends StatelessWidget {
  const _AndroidCalendarEventsDialog({required this.events});

  final List<AndroidCalendarEventPreview> events;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Próximos eventos permitidos'),
    content: SizedBox(
      width: 420,
      child: events.isEmpty
          ? const Text(
              'Não há eventos nos próximos 30 dias nas agendas escolhidas.',
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (BuildContext context, int index) {
                final AndroidCalendarEventPreview event = events[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.title),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(event.startsAt.toLocal())} '
                    'até ${DateFormat('HH:mm', 'pt_BR').format(event.endsAt.toLocal())}',
                  ),
                );
              },
            ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Fechar'),
      ),
    ],
  );
}

class _AndroidCalendarSelectionDialog extends StatefulWidget {
  const _AndroidCalendarSelectionDialog({
    required this.calendars,
    required this.selectedIds,
  });

  final List<AuthorizedAndroidCalendar> calendars;
  final Set<String> selectedIds;

  @override
  State<_AndroidCalendarSelectionDialog> createState() =>
      _AndroidCalendarSelectionDialogState();
}

class _AndroidCalendarSelectionDialogState
    extends State<_AndroidCalendarSelectionDialog> {
  late final Set<String> _selected = Set<String>.of(widget.selectedIds);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Calendários permitidos'),
    content: SizedBox(
      width: 420,
      child: widget.calendars.isEmpty
          ? const Text('Nenhum calendário disponível no aparelho.')
          : ListView(
              shrinkWrap: true,
              children: <Widget>[
                const Text(
                  'Selecione somente as agendas que podem ser lidas. Esta escolha não cria nem altera eventos.',
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final AuthorizedAndroidCalendar calendar
                    in widget.calendars)
                  CheckboxListTile(
                    value: _selected.contains(calendar.calendarId),
                    title: Text(calendar.displayName),
                    onChanged: (bool? value) => setState(() {
                      if (value ?? false) {
                        _selected.add(calendar.calendarId);
                      } else {
                        _selected.remove(calendar.calendarId);
                      }
                    }),
                  ),
              ],
            ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('Salvar seleção'),
      ),
    ],
  );
}

class _AssistantCalendarNotice extends StatelessWidget {
  const _AssistantCalendarNotice();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.auto_awesome_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'Assistente: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        'poderá consultar esta agenda e propor lembretes. Nunca paga, recebe, conclui ou altera um compromisso financeiro sem confirmação explícita.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MissingTemplateNotice extends StatelessWidget {
  const _MissingTemplateNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Uma previsão local não encontrou seu compromisso-modelo confirmado e não será exibida. Nenhum valor foi inventado.',
    ),
  );
}

class _CalendarLoadFailure extends StatelessWidget {
  const _CalendarLoadFailure({this.onRetry});

  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Não foi possível confirmar a agenda financeira. Nenhum valor será mostrado sem leitura confirmada.',
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CreateRecurrenceDialog extends StatefulWidget {
  const _CreateRecurrenceDialog({required this.templates});

  final List<FinancialCommitment> templates;

  @override
  State<_CreateRecurrenceDialog> createState() =>
      _CreateRecurrenceDialogState();
}

class _CreateRecurrenceDialogState extends State<_CreateRecurrenceDialog> {
  late FinancialCommitment _template = widget.templates.first;
  FinancialCalendarRecurrenceFrequency _frequency =
      FinancialCalendarRecurrenceFrequency.monthly;
  int _interval = 1;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova previsão recorrente'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<FinancialCommitment>(
            initialValue: _template,
            decoration: const InputDecoration(labelText: 'Compromisso-modelo'),
            items: widget.templates
                .map(
                  (FinancialCommitment value) =>
                      DropdownMenuItem<FinancialCommitment>(
                        value: value,
                        child: Text(
                          value.description,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                )
                .toList(growable: false),
            onChanged: (FinancialCommitment? value) {
              if (value != null) setState(() => _template = value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<FinancialCalendarRecurrenceFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: FinancialCalendarRecurrenceFrequency.values
                .map(
                  (FinancialCalendarRecurrenceFrequency value) =>
                      DropdownMenuItem<FinancialCalendarRecurrenceFrequency>(
                        value: value,
                        child: Text(value.label),
                      ),
                )
                .toList(growable: false),
            onChanged: (FinancialCalendarRecurrenceFrequency? value) {
              if (value != null) setState(() => _frequency = value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: '1',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Intervalo',
              helperText: 'Ex.: a cada 1 mês ou 2 semanas.',
            ),
            onChanged: (String value) => _interval = int.tryParse(value) ?? 0,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A primeira previsão será posterior ao vencimento-modelo (${formatCivilDate(_template.dueDate)}). Nenhum compromisso real será criado.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _interval < 1 || _interval > 120
            ? null
            : () => Navigator.of(context).pop(
                FinancialCalendarRecurrenceDraft(
                  sourceKind: _template.kind,
                  sourceCommitmentId: _template.id,
                  frequency: _frequency,
                  interval: _interval,
                  anchorDate: _template.dueDate,
                  endsOn: null,
                ),
              ),
        child: const Text('Salvar previsão'),
      ),
    ],
  );
}

Color _entryColor(
  BuildContext context,
  FinancialCalendarEntryStatus status,
) => switch (status) {
  FinancialCalendarEntryStatus.overdue => Theme.of(context).colorScheme.error,
  FinancialCalendarEntryStatus.paid || FinancialCalendarEntryStatus.received =>
    Theme.of(context).colorScheme.primary,
  FinancialCalendarEntryStatus.cancelled ||
  FinancialCalendarEntryStatus.voided => Theme.of(context).colorScheme.outline,
  FinancialCalendarEntryStatus.forecast => Theme.of(
    context,
  ).colorScheme.tertiary,
  FinancialCalendarEntryStatus.pending => Theme.of(
    context,
  ).colorScheme.onSurface,
};

SaoPauloCivilDate _monthEnd(SaoPauloCivilDate month) {
  final DateTime day = DateTime.utc(month.year, month.month + 1, 0);
  return SaoPauloCivilDate(year: day.year, month: day.month, day: day.day);
}

SaoPauloCivilDate _addMonths(SaoPauloCivilDate date, int delta) {
  final DateTime firstDay = DateTime.utc(date.year, date.month + delta, 1);
  final int lastDay = DateTime.utc(firstDay.year, firstDay.month + 1, 0).day;
  return SaoPauloCivilDate(
    year: firstDay.year,
    month: firstDay.month,
    day: date.day > lastDay ? lastDay : date.day,
  );
}

String _monthLabel(SaoPauloCivilDate date) =>
    DateFormat('MMMM yyyy', 'pt_BR').format(date.toUtcCalendarDate());
