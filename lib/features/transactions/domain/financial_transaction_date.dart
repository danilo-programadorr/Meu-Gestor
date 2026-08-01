import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

abstract final class FinancialTransactionDate {
  static const Duration saoPauloUtcOffset = Duration(hours: 3);

  static DateTime fromCalendarDate(DateTime selectedDate) => DateTime.utc(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    saoPauloUtcOffset.inHours,
  );

  static DateTime saoPauloCalendarDate(DateTime instant) {
    final DateTime localFields = instant.toUtc().subtract(saoPauloUtcOffset);
    return DateTime.utc(localFields.year, localFields.month, localFields.day);
  }

  static DateTime todayInSaoPaulo(DateTime now) => saoPauloCalendarDate(now);

  static bool isFutureDate(DateTime occurredAt, DateTime now) =>
      saoPauloCalendarDate(occurredAt).isAfter(todayInSaoPaulo(now));

  static void validateNotFuture(DateTime occurredAt, DateTime now) {
    if (isFutureDate(occurredAt, now)) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.futureDate,
        safeMessage: 'Escolha uma data de hoje ou anterior.',
        code: 'future_transaction_date',
      );
    }
  }

  static bool isInMonth(DateTime instant, DateTime reference) {
    return FinancialMonthInterval.fromReference(reference).contains(instant);
  }
}

final class FinancialMonthInterval {
  const FinancialMonthInterval({required this.start, required this.end});

  factory FinancialMonthInterval.fromReference(DateTime reference) {
    final DateTime civilReference =
        FinancialTransactionDate.saoPauloCalendarDate(reference);
    return FinancialMonthInterval(
      start: DateTime.utc(civilReference.year, civilReference.month),
      end: DateTime.utc(civilReference.year, civilReference.month + 1),
    );
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime instant) {
    final DateTime civilDate = FinancialTransactionDate.saoPauloCalendarDate(
      instant,
    );
    return !civilDate.isBefore(start) && civilDate.isBefore(end);
  }
}
