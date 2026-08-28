import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';

enum FinancialCalendarRecurrenceFrequency { weekly, monthly, yearly }

extension FinancialCalendarRecurrenceFrequencyLabel
    on FinancialCalendarRecurrenceFrequency {
  String get label => switch (this) {
    FinancialCalendarRecurrenceFrequency.weekly => 'Semanal',
    FinancialCalendarRecurrenceFrequency.monthly => 'Mensal',
    FinancialCalendarRecurrenceFrequency.yearly => 'Anual',
  };
}

/// Plano local que projeta vencimentos a partir de um compromisso existente.
///
/// Não é uma conta a pagar/receber, não cria lançamento e não altera saldo.
/// O compromisso-modelo continua sendo a única fonte dos dados financeiros.
final class FinancialCalendarRecurrence {
  FinancialCalendarRecurrence({
    required this.id,
    required this.sourceKind,
    required this.sourceCommitmentId,
    required this.frequency,
    required this.interval,
    required this.anchorDate,
    required this.endsOn,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
  }) {
    _validateId(id, field: 'recorrência');
    _validateId(sourceCommitmentId, field: 'compromisso-modelo');
    if (interval < 1 || interval > 120 || updatedAt.isBefore(createdAt)) {
      throw ArgumentError.value(this, 'recurrence', 'Recorrência inválida.');
    }
    if (endsOn != null && endsOn!.isBefore(anchorDate)) {
      throw ArgumentError.value(endsOn, 'endsOn', 'Fim anterior ao início.');
    }
    if (isActive == (cancelledAt != null)) {
      throw ArgumentError.value(
        cancelledAt,
        'cancelledAt',
        'O estado da recorrência é incompatível.',
      );
    }
  }

  final String id;
  final FinancialCommitmentKind sourceKind;
  final String sourceCommitmentId;
  final FinancialCalendarRecurrenceFrequency frequency;
  final int interval;
  final SaoPauloCivilDate anchorDate;
  final SaoPauloCivilDate? endsOn;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;

  FinancialCalendarRecurrence cancel({required DateTime now}) {
    if (!isActive || !now.isUtc) {
      throw StateError('Esta recorrência não pode ser cancelada.');
    }
    return FinancialCalendarRecurrence(
      id: id,
      sourceKind: sourceKind,
      sourceCommitmentId: sourceCommitmentId,
      frequency: frequency,
      interval: interval,
      anchorDate: anchorDate,
      endsOn: endsOn,
      isActive: false,
      createdAt: createdAt,
      updatedAt: now,
      cancelledAt: now,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'sourceKind': sourceKind.name,
    'sourceCommitmentId': sourceCommitmentId,
    'frequency': frequency.name,
    'interval': interval,
    'anchorDate': anchorDate.toString(),
    'endsOn': endsOn?.toString(),
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
  };

  static FinancialCalendarRecurrence fromJson(Map<String, Object?> json) {
    T requireValue<T>(String key) {
      final Object? value = json[key];
      if (value is! T) {
        throw FormatException('Campo local de recorrência inválido: $key.');
      }
      return value;
    }

    SaoPauloCivilDate readDate(String value) {
      final List<String> parts = value.split('-');
      if (parts.length != 3) {
        throw const FormatException('Data local inválida.');
      }
      return SaoPauloCivilDate(
        year: int.parse(parts[0]),
        month: int.parse(parts[1]),
        day: int.parse(parts[2]),
      );
    }

    DateTime readUtc(String value) {
      final DateTime valueDate = DateTime.parse(value);
      if (!valueDate.isUtc) {
        throw const FormatException('Instante local inválido.');
      }
      return valueDate;
    }

    final String? endsOnValue = json['endsOn'] as String?;
    final String? cancelledAtValue = json['cancelledAt'] as String?;
    return FinancialCalendarRecurrence(
      id: requireValue<String>('id'),
      sourceKind: FinancialCommitmentKind.values.byName(
        requireValue<String>('sourceKind'),
      ),
      sourceCommitmentId: requireValue<String>('sourceCommitmentId'),
      frequency: FinancialCalendarRecurrenceFrequency.values.byName(
        requireValue<String>('frequency'),
      ),
      interval: requireValue<int>('interval'),
      anchorDate: readDate(requireValue<String>('anchorDate')),
      endsOn: endsOnValue == null ? null : readDate(endsOnValue),
      isActive: requireValue<bool>('isActive'),
      createdAt: readUtc(requireValue<String>('createdAt')),
      updatedAt: readUtc(requireValue<String>('updatedAt')),
      cancelledAt: cancelledAtValue == null ? null : readUtc(cancelledAtValue),
    );
  }
}

final class FinancialCalendarRecurrenceDraft {
  const FinancialCalendarRecurrenceDraft({
    required this.sourceKind,
    required this.sourceCommitmentId,
    required this.frequency,
    required this.interval,
    required this.anchorDate,
    required this.endsOn,
  });

  final FinancialCommitmentKind sourceKind;
  final String sourceCommitmentId;
  final FinancialCalendarRecurrenceFrequency frequency;
  final int interval;
  final SaoPauloCivilDate anchorDate;
  final SaoPauloCivilDate? endsOn;

  FinancialCalendarRecurrenceDraft normalized() {
    _validateId(sourceCommitmentId, field: 'compromisso-modelo');
    if (interval < 1 || interval > 120) {
      throw ArgumentError.value(interval, 'interval', 'Intervalo inválido.');
    }
    if (endsOn != null && endsOn!.isBefore(anchorDate)) {
      throw ArgumentError.value(endsOn, 'endsOn', 'Fim anterior ao início.');
    }
    return this;
  }
}

void _validateId(String value, {required String field}) {
  if (value.trim().isEmpty || value.length > 150 || value.contains('/')) {
    throw ArgumentError.value(value, field, 'Identificador inválido.');
  }
}
