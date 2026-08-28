import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/shared_preferences_calendar_recurrence_repository.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesCalendarRecurrenceRepository repository;

  final FinancialCalendarRecurrenceDraft draft =
      FinancialCalendarRecurrenceDraft(
        sourceKind: FinancialCommitmentKind.payable,
        sourceCommitmentId: 'payable-model',
        frequency: FinancialCalendarRecurrenceFrequency.monthly,
        interval: 1,
        anchorDate: SaoPauloCivilDate(year: 2026, month: 8, day: 31),
        endsOn: null,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesCalendarRecurrenceRepository(
      preferences: preferences,
      now: () => DateTime.utc(2026, 8, 10, 12),
    );
  });

  test('persiste somente plano sem copiar dados financeiros', () async {
    await repository.createOwn(ownerId: 'owner-a', draft: draft);

    final List<String>? raw = preferences.getStringList(
      'calendar_recurrences_v1_owner-a',
    );
    expect(raw, hasLength(1));
    final Map<String, Object?> json = Map<String, Object?>.from(
      jsonDecode(raw!.single) as Map<String, Object?>,
    );
    expect(
      json.keys,
      isNot(containsAll(<String>['amountCents', 'description', 'categoryId'])),
    );
    expect(json['sourceCommitmentId'], 'payable-model');
  });

  test('isola planos por usuário e torna criação igual idempotente', () async {
    final FinancialCalendarRecurrence first = await repository.createOwn(
      ownerId: 'owner-a',
      draft: draft,
    );
    final FinancialCalendarRecurrence repeated = await repository.createOwn(
      ownerId: 'owner-a',
      draft: draft,
    );
    await repository.createOwn(ownerId: 'owner-b', draft: draft);

    expect(repeated.id, first.id);
    expect(await repository.readOwn(ownerId: 'owner-a'), hasLength(1));
    expect(await repository.readOwn(ownerId: 'owner-b'), hasLength(1));
  });

  test(
    'cancelamento preserva registro e não permite restauração implícita',
    () async {
      final FinancialCalendarRecurrence created = await repository.createOwn(
        ownerId: 'owner-a',
        draft: draft,
      );

      final FinancialCalendarRecurrence cancelled = await repository.cancelOwn(
        ownerId: 'owner-a',
        recurrenceId: created.id,
      );

      expect(cancelled.isActive, isFalse);
      expect(cancelled.cancelledAt, DateTime.utc(2026, 8, 10, 12));
      final List<FinancialCalendarRecurrence> persisted = await repository
          .readOwn(ownerId: 'owner-a');
      expect(persisted, hasLength(1));
      expect(persisted.single.isActive, isFalse);
    },
  );
}
