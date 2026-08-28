import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/android_calendar_contract.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 27, 12);
  final AndroidCalendarEventPreview event = AndroidCalendarEventPreview(
    eventId: 'event-1',
    calendarId: 'calendar-allowed',
    title: 'Lembrete financeiro',
    startsAt: now,
    endsAt: now.add(const Duration(hours: 1)),
  );

  test(
    'escrita externa requer calendário autorizado e confirmação recente',
    () {
      final AndroidCalendarWriteConfirmation confirmation =
          AndroidCalendarWriteConfirmation(
            kind: AndroidCalendarExternalWriteKind.create,
            calendarId: 'calendar-allowed',
            eventDigest: 'digest-calendar-123',
            confirmedAt: now,
          );

      expect(
        () => AndroidCalendarWritePolicy.assertAllowed(
          authorizedCalendarIds: <String>{'calendar-allowed'},
          kind: AndroidCalendarExternalWriteKind.create,
          event: event,
          confirmation: confirmation,
          now: now.add(const Duration(minutes: 1)),
        ),
        returnsNormally,
      );
    },
  );

  test('nega escrita sem seleção, confirmação divergente ou expirada', () {
    final AndroidCalendarWriteConfirmation confirmation =
        AndroidCalendarWriteConfirmation(
          kind: AndroidCalendarExternalWriteKind.update,
          calendarId: 'calendar-other',
          eventDigest: 'digest-calendar-123',
          confirmedAt: now,
        );

    expect(
      () => AndroidCalendarWritePolicy.assertAllowed(
        authorizedCalendarIds: <String>{'calendar-allowed'},
        kind: AndroidCalendarExternalWriteKind.create,
        event: event,
        confirmation: confirmation,
        now: now.add(const Duration(minutes: 6)),
      ),
      throwsA(isA<AndroidCalendarConfirmationRequiredException>()),
    );
  });

  test(
    'gateway padrão falha fechado sem ler ou escrever dados Android',
    () async {
      const UnavailableAndroidCalendarGateway gateway =
          UnavailableAndroidCalendarGateway();

      await expectLater(
        gateway.listCalendars(),
        throwsA(isA<AndroidCalendarUnavailableException>()),
      );
      await expectLater(
        gateway.readAuthorizedEvents(
          authorizedCalendarIds: <String>{'calendar-allowed'},
          startsAt: now,
          endsAt: now.add(const Duration(days: 1)),
        ),
        throwsA(isA<AndroidCalendarUnavailableException>()),
      );
    },
  );
}
