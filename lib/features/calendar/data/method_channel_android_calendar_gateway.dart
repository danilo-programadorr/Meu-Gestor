import 'package:flutter/services.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/android_calendar_contract.dart';

final class MethodChannelAndroidCalendarGateway
    implements AndroidCalendarGateway {
  const MethodChannelAndroidCalendarGateway({
    MethodChannel channel = const MethodChannel(
      'br.com.hellenfaro.meugestorfinanceiro/android_calendar',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<List<AuthorizedAndroidCalendar>> listCalendars() async {
    return _listCalendars('listCalendars');
  }

  @override
  Future<List<AuthorizedAndroidCalendar>> listWritableCalendars() async {
    return _listCalendars('listWritableCalendars');
  }

  Future<List<AuthorizedAndroidCalendar>> _listCalendars(String method) async {
    try {
      final List<Object?>? raw = await _channel.invokeListMethod<Object?>(
        method,
      );
      return List<AuthorizedAndroidCalendar>.unmodifiable(
        (raw ?? const <Object?>[]).map(_calendarFromPlatform),
      );
    } on PlatformException {
      throw const AndroidCalendarUnavailableException();
    } on MissingPluginException {
      throw const AndroidCalendarUnavailableException();
    }
  }

  @override
  Future<List<AndroidCalendarEventPreview>> readAuthorizedEvents({
    required Set<String> authorizedCalendarIds,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if (!startsAt.isUtc ||
        !endsAt.isUtc ||
        !startsAt.isBefore(endsAt) ||
        authorizedCalendarIds.isEmpty) {
      throw const AndroidCalendarUnavailableException();
    }
    try {
      final List<Object?>? raw = await _channel
          .invokeListMethod<Object?>('readAuthorizedEvents', <String, Object>{
            'calendarIds': authorizedCalendarIds.toList(growable: false),
            'startsAtMillis': startsAt.millisecondsSinceEpoch,
            'endsAtMillis': endsAt.millisecondsSinceEpoch,
          });
      return List<AndroidCalendarEventPreview>.unmodifiable(
        (raw ?? const <Object?>[]).map(_eventFromPlatform),
      );
    } on PlatformException {
      throw const AndroidCalendarUnavailableException();
    } on MissingPluginException {
      throw const AndroidCalendarUnavailableException();
    }
  }

  @override
  Future<void> writeConfirmedEvent({
    required Set<String> authorizedCalendarIds,
    required AndroidCalendarExternalWriteKind kind,
    required AndroidCalendarEventDraft event,
    required AndroidCalendarWriteConfirmation confirmation,
  }) async {
    AndroidCalendarWritePolicy.assertAllowed(
      authorizedCalendarIds: authorizedCalendarIds,
      kind: kind,
      event: event,
      confirmation: confirmation,
      now: DateTime.now().toUtc(),
    );
    if (kind != AndroidCalendarExternalWriteKind.create) {
      throw const AndroidCalendarUnavailableException();
    }
    try {
      await _channel
          .invokeMethod<void>('createConfirmedEvent', <String, Object>{
            'calendarId': event.calendarId,
            'title': event.title,
            'startsAtMillis': event.startsAt.millisecondsSinceEpoch,
            'endsAtMillis': event.endsAt.millisecondsSinceEpoch,
          });
    } on PlatformException {
      throw const AndroidCalendarUnavailableException();
    } on MissingPluginException {
      throw const AndroidCalendarUnavailableException();
    }
  }

  AuthorizedAndroidCalendar _calendarFromPlatform(Object? value) {
    if (value is! Map) {
      throw const AndroidCalendarUnavailableException();
    }
    final Object? id = value['id'];
    final Object? displayName = value['displayName'];
    if (id is! String ||
        id.isEmpty ||
        displayName is! String ||
        displayName.isEmpty) {
      throw const AndroidCalendarUnavailableException();
    }
    return AuthorizedAndroidCalendar(calendarId: id, displayName: displayName);
  }

  AndroidCalendarEventPreview _eventFromPlatform(Object? value) {
    if (value is! Map) {
      throw const AndroidCalendarUnavailableException();
    }
    final Object? id = value['id'];
    final Object? calendarId = value['calendarId'];
    final Object? title = value['title'];
    final Object? startsAtMillis = value['startsAtMillis'];
    final Object? endsAtMillis = value['endsAtMillis'];
    if (id is! String ||
        calendarId is! String ||
        title is! String ||
        startsAtMillis is! int ||
        endsAtMillis is! int) {
      throw const AndroidCalendarUnavailableException();
    }
    return AndroidCalendarEventPreview(
      eventId: id,
      calendarId: calendarId,
      title: title,
      startsAt: DateTime.fromMillisecondsSinceEpoch(
        startsAtMillis,
        isUtc: true,
      ),
      endsAt: DateTime.fromMillisecondsSinceEpoch(endsAtMillis, isUtc: true),
    );
  }
}
