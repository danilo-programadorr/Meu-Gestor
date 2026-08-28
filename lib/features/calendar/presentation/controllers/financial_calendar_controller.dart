import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/shared_preferences_calendar_recurrence_repository.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/financial_calendar_recurrence_repository.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FutureProvider<FinancialCalendarRecurrenceRepository>
calendarRecurrenceRepositoryProvider =
    FutureProvider<FinancialCalendarRecurrenceRepository>((Ref ref) async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      return SharedPreferencesCalendarRecurrenceRepository(
        preferences: preferences,
        now: ref.read(financialClockProvider),
      );
    });

final AsyncNotifierProvider<
  FinancialCalendarController,
  List<FinancialCalendarRecurrence>
>
calendarRecurrencesControllerProvider =
    AsyncNotifierProvider<
      FinancialCalendarController,
      List<FinancialCalendarRecurrence>
    >(FinancialCalendarController.new);

final class FinancialCalendarController
    extends AsyncNotifier<List<FinancialCalendarRecurrence>> {
  @override
  Future<List<FinancialCalendarRecurrence>> build() => _read();

  Future<void> refresh() async {
    state = const AsyncLoading<List<FinancialCalendarRecurrence>>();
    state = await AsyncValue.guard<List<FinancialCalendarRecurrence>>(_read);
  }

  Future<bool> create(FinancialCalendarRecurrenceDraft draft) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<List<FinancialCalendarRecurrence>>();
    try {
      final FinancialCalendarRecurrence created = await (await _repository)
          .createOwn(ownerId: _ownerId, draft: draft);
      final List<FinancialCalendarRecurrence> current = await _read();
      if (!current.any(
        (FinancialCalendarRecurrence item) => item.id == created.id,
      )) {
        throw const CalendarRecurrenceStorageFailure();
      }
      state = AsyncData<List<FinancialCalendarRecurrence>>(current);
      return true;
    } on Object {
      state = AsyncError<List<FinancialCalendarRecurrence>>(
        const CalendarRecurrenceStorageFailure(),
        StackTrace.current,
      );
      return false;
    }
  }

  Future<bool> cancel(String recurrenceId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<List<FinancialCalendarRecurrence>>();
    try {
      await (await _repository).cancelOwn(
        ownerId: _ownerId,
        recurrenceId: recurrenceId,
      );
      state = AsyncData<List<FinancialCalendarRecurrence>>(await _read());
      return true;
    } on Object {
      state = AsyncError<List<FinancialCalendarRecurrence>>(
        const CalendarRecurrenceStorageFailure(),
        StackTrace.current,
      );
      return false;
    }
  }

  Future<List<FinancialCalendarRecurrence>> _read() async =>
      List<FinancialCalendarRecurrence>.unmodifiable(
        await (await _repository).readOwn(ownerId: _ownerId),
      );

  String get _ownerId {
    final String? ownerId = verifiedFinancialOwner(ref);
    if (ownerId == null) throw const CalendarRecurrenceOwnerFailure();
    return ownerId;
  }

  Future<FinancialCalendarRecurrenceRepository> get _repository =>
      ref.read(calendarRecurrenceRepositoryProvider.future);
}
