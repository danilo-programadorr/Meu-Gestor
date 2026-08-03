import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';

void main() {
  group('SaoPauloCivilDate', () {
    test('converte calendário para a convenção persistida de 03:00 UTC', () {
      final SaoPauloCivilDate date = SaoPauloCivilDate.fromCalendarDate(
        DateTime(2026, 8, 2, 18, 45),
      );

      expect(date, SaoPauloCivilDate(year: 2026, month: 8, day: 2));
      expect(date.toStorageInstant(), DateTime.utc(2026, 8, 2, 3));
      expect(date.toUtcCalendarDate(), DateTime.utc(2026, 8, 2));
      expect(date.toString(), '2026-08-02');
    });

    test('respeita a virada da meia-noite de São Paulo', () {
      expect(
        SaoPauloCivilDate.fromInstant(DateTime.utc(2026, 8, 2, 2, 59)),
        SaoPauloCivilDate(year: 2026, month: 8, day: 1),
      );
      expect(
        SaoPauloCivilDate.fromInstant(DateTime.utc(2026, 8, 2, 3)),
        SaoPauloCivilDate(year: 2026, month: 8, day: 2),
      );
    });

    test('compara datas em meses e anos diferentes', () {
      final SaoPauloCivilDate endOfYear = SaoPauloCivilDate(
        year: 2026,
        month: 12,
        day: 31,
      );
      final SaoPauloCivilDate nextYear = SaoPauloCivilDate(
        year: 2027,
        month: 1,
        day: 1,
      );

      expect(endOfYear.isBefore(nextYear), isTrue);
      expect(nextYear.isAfter(endOfYear), isTrue);
      expect(endOfYear.compareTo(endOfYear), 0);
    });

    test('aceita ano bissexto e rejeita datas inexistentes', () {
      expect(
        SaoPauloCivilDate(year: 2028, month: 2, day: 29),
        SaoPauloCivilDate.fromCalendarDate(DateTime(2028, 2, 29)),
      );
      expect(
        () => SaoPauloCivilDate(year: 2027, month: 2, day: 29),
        throwsArgumentError,
      );
      expect(
        () => SaoPauloCivilDate(year: 2026, month: 13, day: 1),
        throwsArgumentError,
      );
    });
  });
}
