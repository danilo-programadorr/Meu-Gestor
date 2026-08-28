import 'financial_calendar_recurrence.dart';

abstract interface class FinancialCalendarRecurrenceRepository {
  Future<List<FinancialCalendarRecurrence>> readOwn({required String ownerId});

  Future<FinancialCalendarRecurrence> createOwn({
    required String ownerId,
    required FinancialCalendarRecurrenceDraft draft,
  });

  Future<FinancialCalendarRecurrence> cancelOwn({
    required String ownerId,
    required String recurrenceId,
  });
}
