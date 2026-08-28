/// Contrato para uma integração futura com o provedor de calendário Android.
/// Nada deste contrato acessa Google Calendar, rede ou dados do aparelho.
enum AndroidCalendarExternalWriteKind { create, update, delete }

final class AuthorizedAndroidCalendar {
  const AuthorizedAndroidCalendar({
    required this.calendarId,
    required this.displayName,
  }) : assert(calendarId != ''),
       assert(displayName != '');

  final String calendarId;
  final String displayName;
}

final class AndroidCalendarEventPreview {
  const AndroidCalendarEventPreview({
    required this.eventId,
    required this.calendarId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
  });

  final String eventId;
  final String calendarId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
}

final class AndroidCalendarWriteConfirmation {
  const AndroidCalendarWriteConfirmation({
    required this.kind,
    required this.calendarId,
    required this.eventDigest,
    required this.confirmedAt,
  });

  final AndroidCalendarExternalWriteKind kind;
  final String calendarId;
  final String eventDigest;
  final DateTime confirmedAt;
}

abstract final class AndroidCalendarWritePolicy {
  static const Duration maximumConfirmationAge = Duration(minutes: 5);

  static void assertAllowed({
    required Set<String> authorizedCalendarIds,
    required AndroidCalendarExternalWriteKind kind,
    required AndroidCalendarEventPreview event,
    required AndroidCalendarWriteConfirmation confirmation,
    required DateTime now,
  }) {
    if (!now.isUtc ||
        !confirmation.confirmedAt.isUtc ||
        !authorizedCalendarIds.contains(event.calendarId) ||
        confirmation.kind != kind ||
        confirmation.calendarId != event.calendarId ||
        confirmation.eventDigest.trim().length < 16 ||
        now.difference(confirmation.confirmedAt).isNegative ||
        now.difference(confirmation.confirmedAt) > maximumConfirmationAge) {
      throw const AndroidCalendarConfirmationRequiredException();
    }
  }
}

abstract interface class AndroidCalendarGateway {
  Future<List<AuthorizedAndroidCalendar>> listCalendars();

  /// Deve retornar eventos apenas dos IDs previamente autorizados pelo usuário.
  Future<List<AndroidCalendarEventPreview>> readAuthorizedEvents({
    required Set<String> authorizedCalendarIds,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  /// Toda escrita exige confirmação de interface fresca e específica ao evento.
  Future<void> writeConfirmedEvent({
    required AndroidCalendarExternalWriteKind kind,
    required AndroidCalendarEventPreview event,
    required AndroidCalendarWriteConfirmation confirmation,
  });
}

/// Implementação segura para este checkpoint: não pede permissão, não lê e
/// não escreve no provedor Android. A ponte nativa depende de autorização
/// própria e deve manter este mesmo contrato.
final class UnavailableAndroidCalendarGateway
    implements AndroidCalendarGateway {
  const UnavailableAndroidCalendarGateway();

  Never _unavailable() => throw const AndroidCalendarUnavailableException();

  @override
  Future<List<AuthorizedAndroidCalendar>> listCalendars() async =>
      _unavailable();

  @override
  Future<List<AndroidCalendarEventPreview>> readAuthorizedEvents({
    required Set<String> authorizedCalendarIds,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => _unavailable();

  @override
  Future<void> writeConfirmedEvent({
    required AndroidCalendarExternalWriteKind kind,
    required AndroidCalendarEventPreview event,
    required AndroidCalendarWriteConfirmation confirmation,
  }) async => _unavailable();
}

final class AndroidCalendarUnavailableException implements Exception {
  const AndroidCalendarUnavailableException();
}

final class AndroidCalendarConfirmationRequiredException implements Exception {
  const AndroidCalendarConfirmationRequiredException();
}
