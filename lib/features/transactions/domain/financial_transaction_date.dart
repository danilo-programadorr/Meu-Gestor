import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

abstract final class FinancialTransactionDate {
  static DateTime fromCalendarDate(DateTime selectedDate) =>
      SaoPauloCivilDate.fromCalendarDate(selectedDate).toStorageInstant();

  static DateTime saoPauloCalendarDate(DateTime instant) =>
      SaoPauloCivilDate.fromInstant(instant).toUtcCalendarDate();

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
