import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';

enum FinancialCalendarEntryStatus {
  pending,
  overdue,
  paid,
  received,
  cancelled,
  voided,
  forecast,
}

extension FinancialCalendarEntryStatusLabel on FinancialCalendarEntryStatus {
  String get label => switch (this) {
    FinancialCalendarEntryStatus.pending => 'Pendente',
    FinancialCalendarEntryStatus.overdue => 'Atrasado',
    FinancialCalendarEntryStatus.paid => 'Pago',
    FinancialCalendarEntryStatus.received => 'Recebido',
    FinancialCalendarEntryStatus.cancelled => 'Cancelado',
    FinancialCalendarEntryStatus.voided => 'Anulado',
    FinancialCalendarEntryStatus.forecast => 'Previsão recorrente',
  };
}

final class FinancialCalendarEntry {
  const FinancialCalendarEntry({
    required this.id,
    required this.sourceCommitmentId,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.dueDate,
    required this.movementDate,
    required this.status,
    required this.recurrenceId,
  });

  final String id;
  final String sourceCommitmentId;
  final FinancialCommitmentKind kind;
  final String description;
  final int amountCents;
  final SaoPauloCivilDate dueDate;
  final SaoPauloCivilDate? movementDate;
  final FinancialCalendarEntryStatus status;
  final String? recurrenceId;

  bool get isForecast => status == FinancialCalendarEntryStatus.forecast;

  bool get isIncoming => kind == FinancialCommitmentKind.receivable;

  bool get affectsRealBalance => !isForecast && movementDate != null;
}

final class FinancialCalendarForecast {
  const FinancialCalendarForecast({
    required this.incomingCents,
    required this.outgoingCents,
    required this.entryCount,
  });

  final int incomingCents;
  final int outgoingCents;
  final int entryCount;

  int get netCents => incomingCents - outgoingCents;
}

final class FinancialCalendarProjection {
  const FinancialCalendarProjection({
    required this.today,
    required this.entries,
    required this.missingRecurrenceSourceIds,
  });

  final SaoPauloCivilDate today;
  final List<FinancialCalendarEntry> entries;
  final Set<String> missingRecurrenceSourceIds;

  List<FinancialCalendarEntry> entriesOn(SaoPauloCivilDate date) => entries
      .where((FinancialCalendarEntry entry) => entry.dueDate == date)
      .toList(growable: false);

  List<FinancialCalendarEntry> get upcoming => entries
      .where(
        (FinancialCalendarEntry entry) =>
            entry.dueDate.compareTo(today) >= 0 &&
            (entry.status == FinancialCalendarEntryStatus.pending ||
                entry.status == FinancialCalendarEntryStatus.forecast),
      )
      .toList(growable: false);

  FinancialCalendarForecast forecastUntil(SaoPauloCivilDate endInclusive) {
    int incoming = 0;
    int outgoing = 0;
    int count = 0;
    for (final FinancialCalendarEntry entry in entries) {
      if (entry.dueDate.isBefore(today) ||
          entry.dueDate.isAfter(endInclusive)) {
        continue;
      }
      if (entry.status != FinancialCalendarEntryStatus.pending &&
          entry.status != FinancialCalendarEntryStatus.forecast) {
        continue;
      }
      count += 1;
      if (entry.isIncoming) {
        incoming += entry.amountCents;
      } else {
        outgoing += entry.amountCents;
      }
    }
    return FinancialCalendarForecast(
      incomingCents: incoming,
      outgoingCents: outgoing,
      entryCount: count,
    );
  }
}

abstract final class FinancialCalendarProjector {
  static FinancialCalendarProjection project({
    required SaoPauloCivilDate today,
    required Iterable<Payable> payables,
    required Iterable<Receivable> receivables,
    required Iterable<FinancialCalendarRecurrence> recurrences,
    required SaoPauloCivilDate horizonEnd,
  }) {
    final List<FinancialCommitment> commitments = <FinancialCommitment>[
      ...payables,
      ...receivables,
    ];
    final Map<String, FinancialCommitment> sources =
        <String, FinancialCommitment>{
          for (final FinancialCommitment commitment in commitments)
            _sourceKey(commitment.kind, commitment.id): commitment,
        };
    final List<FinancialCalendarEntry> entries = commitments
        .map(
          (FinancialCommitment commitment) => FinancialCalendarEntry(
            id: 'commitment:${commitment.kind.name}:${commitment.id}',
            sourceCommitmentId: commitment.id,
            kind: commitment.kind,
            description: commitment.description,
            amountCents: commitment.amountCents,
            dueDate: commitment.dueDate,
            movementDate: commitment.movementDate,
            status: _statusFor(commitment, today),
            recurrenceId: null,
          ),
        )
        .toList(growable: true);
    final Set<String> missing = <String>{};

    for (final FinancialCalendarRecurrence recurrence in recurrences) {
      if (!recurrence.isActive) continue;
      final FinancialCommitment? source =
          sources[_sourceKey(
            recurrence.sourceKind,
            recurrence.sourceCommitmentId,
          )];
      if (source == null) {
        missing.add(recurrence.sourceCommitmentId);
        continue;
      }
      for (final SaoPauloCivilDate dueDate in _occurrences(
        recurrence: recurrence,
        horizonStart: today,
        horizonEnd: horizonEnd,
      )) {
        entries.add(
          FinancialCalendarEntry(
            id: 'recurrence:${recurrence.id}:$dueDate',
            sourceCommitmentId: source.id,
            kind: source.kind,
            description: source.description,
            amountCents: source.amountCents,
            dueDate: dueDate,
            movementDate: null,
            status: FinancialCalendarEntryStatus.forecast,
            recurrenceId: recurrence.id,
          ),
        );
      }
    }
    entries.sort((FinancialCalendarEntry first, FinancialCalendarEntry second) {
      final int byDate = first.dueDate.compareTo(second.dueDate);
      if (byDate != 0) return byDate;
      final int byForecast = first.isForecast == second.isForecast
          ? 0
          : first.isForecast
          ? 1
          : -1;
      return byForecast != 0
          ? byForecast
          : first.description.compareTo(second.description);
    });
    return FinancialCalendarProjection(
      today: today,
      entries: List<FinancialCalendarEntry>.unmodifiable(entries),
      missingRecurrenceSourceIds: Set<String>.unmodifiable(missing),
    );
  }

  static FinancialCalendarEntryStatus _statusFor(
    FinancialCommitment commitment,
    SaoPauloCivilDate today,
  ) {
    if (commitment.isOverdue(today)) {
      return FinancialCalendarEntryStatus.overdue;
    }
    if (commitment.isPending) return FinancialCalendarEntryStatus.pending;
    if (commitment.isCancelled) return FinancialCalendarEntryStatus.cancelled;
    if (commitment.isVoided) return FinancialCalendarEntryStatus.voided;
    return commitment.kind == FinancialCommitmentKind.payable
        ? FinancialCalendarEntryStatus.paid
        : FinancialCalendarEntryStatus.received;
  }

  static Iterable<SaoPauloCivilDate> _occurrences({
    required FinancialCalendarRecurrence recurrence,
    required SaoPauloCivilDate horizonStart,
    required SaoPauloCivilDate horizonEnd,
  }) sync* {
    SaoPauloCivilDate candidate = _next(recurrence.anchorDate, recurrence);
    while (!candidate.isAfter(horizonEnd) &&
        (recurrence.endsOn == null || !candidate.isAfter(recurrence.endsOn!))) {
      if (!candidate.isBefore(horizonStart)) yield candidate;
      candidate = _next(candidate, recurrence);
    }
  }

  static SaoPauloCivilDate _next(
    SaoPauloCivilDate date,
    FinancialCalendarRecurrence recurrence,
  ) => switch (recurrence.frequency) {
    FinancialCalendarRecurrenceFrequency.weekly =>
      SaoPauloCivilDate.fromCalendarDate(
        date.toUtcCalendarDate().add(Duration(days: recurrence.interval * 7)),
      ),
    FinancialCalendarRecurrenceFrequency.monthly => _addMonths(
      date,
      recurrence.interval,
      recurrence.anchorDate.day,
    ),
    FinancialCalendarRecurrenceFrequency.yearly => _addMonths(
      date,
      recurrence.interval * 12,
      recurrence.anchorDate.day,
    ),
  };

  static SaoPauloCivilDate _addMonths(
    SaoPauloCivilDate date,
    int months,
    int preferredDay,
  ) {
    final DateTime firstDay = DateTime.utc(date.year, date.month + months, 1);
    final int lastDay = DateTime.utc(firstDay.year, firstDay.month + 1, 0).day;
    return SaoPauloCivilDate(
      year: firstDay.year,
      month: firstDay.month,
      day: preferredDay > lastDay ? lastDay : preferredDay,
    );
  }

  static String _sourceKey(FinancialCommitmentKind kind, String id) =>
      '${kind.name}:$id';
}
