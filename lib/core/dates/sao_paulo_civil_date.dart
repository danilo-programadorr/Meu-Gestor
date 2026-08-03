final class SaoPauloCivilDate implements Comparable<SaoPauloCivilDate> {
  SaoPauloCivilDate({
    required this.year,
    required this.month,
    required this.day,
  }) {
    final DateTime candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Data civil inválida.',
      );
    }
  }

  factory SaoPauloCivilDate.fromCalendarDate(DateTime date) =>
      SaoPauloCivilDate(year: date.year, month: date.month, day: date.day);

  factory SaoPauloCivilDate.fromInstant(DateTime instant) {
    final DateTime localFields = instant.toUtc().subtract(utcOffset);
    return SaoPauloCivilDate(
      year: localFields.year,
      month: localFields.month,
      day: localFields.day,
    );
  }

  static const Duration utcOffset = Duration(hours: 3);

  final int year;
  final int month;
  final int day;

  DateTime toStorageInstant() =>
      DateTime.utc(year, month, day, utcOffset.inHours);

  DateTime toUtcCalendarDate() => DateTime.utc(year, month, day);

  bool isBefore(SaoPauloCivilDate other) => compareTo(other) < 0;

  bool isAfter(SaoPauloCivilDate other) => compareTo(other) > 0;

  @override
  int compareTo(SaoPauloCivilDate other) {
    final int byYear = year.compareTo(other.year);
    if (byYear != 0) {
      return byYear;
    }
    final int byMonth = month.compareTo(other.month);
    return byMonth != 0 ? byMonth : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaoPauloCivilDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
