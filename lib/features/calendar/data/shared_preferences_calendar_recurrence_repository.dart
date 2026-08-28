import 'dart:convert';

import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Armazena somente a cadência e a referência do compromisso-modelo no
/// dispositivo. Descrição, valor, categoria e lançamentos nunca são copiados:
/// continuam no compromisso confirmado do próprio usuário.
final class SharedPreferencesCalendarRecurrenceRepository
    implements FinancialCalendarRecurrenceRepository {
  SharedPreferencesCalendarRecurrenceRepository({
    required SharedPreferences preferences,
    required DateTime Function() now,
  }) : _preferences = preferences,
       _now = now;

  static const String _keyPrefix = 'calendar_recurrences_v1_';

  final SharedPreferences _preferences;
  final DateTime Function() _now;

  @override
  Future<List<FinancialCalendarRecurrence>> readOwn({
    required String ownerId,
  }) async {
    _validateOwner(ownerId);
    final List<String> values =
        _preferences.getStringList(_key(ownerId)) ?? const <String>[];
    try {
      final List<FinancialCalendarRecurrence> result =
          values
              .map((String encoded) {
                final Object? decoded = jsonDecode(encoded);
                if (decoded is! Map) {
                  throw const FormatException('Plano local incompatível.');
                }
                return FinancialCalendarRecurrence.fromJson(
                  Map<String, Object?>.from(decoded),
                );
              })
              .toList(growable: false)
            ..sort(
              (
                FinancialCalendarRecurrence first,
                FinancialCalendarRecurrence second,
              ) => first.createdAt.compareTo(second.createdAt),
            );
      return List<FinancialCalendarRecurrence>.unmodifiable(result);
    } on Object {
      throw const CalendarRecurrenceStorageFailure();
    }
  }

  @override
  Future<FinancialCalendarRecurrence> createOwn({
    required String ownerId,
    required FinancialCalendarRecurrenceDraft draft,
  }) async {
    _validateOwner(ownerId);
    final FinancialCalendarRecurrenceDraft normalized = draft.normalized();
    final List<FinancialCalendarRecurrence> current = await readOwn(
      ownerId: ownerId,
    );
    FinancialCalendarRecurrence? duplicate;
    for (final FinancialCalendarRecurrence item in current) {
      if (item.isActive &&
          item.sourceKind == normalized.sourceKind &&
          item.sourceCommitmentId == normalized.sourceCommitmentId &&
          item.frequency == normalized.frequency &&
          item.interval == normalized.interval &&
          item.anchorDate == normalized.anchorDate &&
          item.endsOn == normalized.endsOn) {
        duplicate = item;
        break;
      }
    }
    if (duplicate != null) return duplicate;

    final DateTime now = _requireUtc(_now());
    final FinancialCalendarRecurrence created = FinancialCalendarRecurrence(
      id: 'calendar-${now.microsecondsSinceEpoch}-${current.length + 1}',
      sourceKind: normalized.sourceKind,
      sourceCommitmentId: normalized.sourceCommitmentId,
      frequency: normalized.frequency,
      interval: normalized.interval,
      anchorDate: normalized.anchorDate,
      endsOn: normalized.endsOn,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      cancelledAt: null,
    );
    await _write(ownerId, <FinancialCalendarRecurrence>[...current, created]);
    return created;
  }

  @override
  Future<FinancialCalendarRecurrence> cancelOwn({
    required String ownerId,
    required String recurrenceId,
  }) async {
    _validateOwner(ownerId);
    final List<FinancialCalendarRecurrence> current = await readOwn(
      ownerId: ownerId,
    );
    final int index = current.indexWhere(
      (FinancialCalendarRecurrence item) => item.id == recurrenceId,
    );
    if (index < 0) throw const CalendarRecurrenceNotFoundFailure();
    final FinancialCalendarRecurrence existing = current[index];
    if (!existing.isActive) return existing;
    final FinancialCalendarRecurrence cancelled = existing.cancel(
      now: _requireUtc(_now()),
    );
    final List<FinancialCalendarRecurrence> updated =
        List<FinancialCalendarRecurrence>.of(current)..[index] = cancelled;
    await _write(ownerId, updated);
    return cancelled;
  }

  Future<void> _write(
    String ownerId,
    List<FinancialCalendarRecurrence> values,
  ) async {
    final bool persisted = await _preferences.setStringList(
      _key(ownerId),
      values
          .map((FinancialCalendarRecurrence item) => jsonEncode(item.toJson()))
          .toList(growable: false),
    );
    if (!persisted) throw const CalendarRecurrenceStorageFailure();
  }

  String _key(String ownerId) => '$_keyPrefix$ownerId';

  void _validateOwner(String ownerId) {
    if (ownerId.isEmpty || ownerId.length > 150 || ownerId.contains('/')) {
      throw const CalendarRecurrenceOwnerFailure();
    }
  }

  DateTime _requireUtc(DateTime value) {
    final DateTime utc = value.toUtc();
    if (utc.year < 2020) throw const CalendarRecurrenceStorageFailure();
    return utc;
  }
}

final class CalendarRecurrenceStorageFailure implements Exception {
  const CalendarRecurrenceStorageFailure();
}

final class CalendarRecurrenceNotFoundFailure implements Exception {
  const CalendarRecurrenceNotFoundFailure();
}

final class CalendarRecurrenceOwnerFailure implements Exception {
  const CalendarRecurrenceOwnerFailure();
}
