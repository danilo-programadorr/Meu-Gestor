import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/method_channel_android_calendar_gateway.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/android_calendar_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('calendar-test');
  const MethodChannelAndroidCalendarGateway gateway =
      MethodChannelAndroidCalendarGateway(channel: channel);
  final DateTime now = DateTime.utc(2026, 10, 15, 18);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('envia criação somente depois de validar seleção e digest', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          received = call;
          return null;
        });
    final AndroidCalendarEventDraft event = AndroidCalendarEventDraft(
      calendarId: '42',
      title: 'Consulta no dentista',
      startsAt: now.add(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
      previewDigest: 'digest-calendar-123',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    await gateway.writeConfirmedEvent(
      authorizedCalendarIds: <String>{'42'},
      kind: AndroidCalendarExternalWriteKind.create,
      event: event,
      confirmation: AndroidCalendarWriteConfirmation(
        kind: AndroidCalendarExternalWriteKind.create,
        calendarId: '42',
        eventDigest: 'digest-calendar-123',
        confirmedAt: DateTime.now().toUtc(),
      ),
    );

    expect(received?.method, 'createConfirmedEvent');
    expect(received?.arguments, <String, Object>{
      'calendarId': '42',
      'title': 'Consulta no dentista',
      'startsAtMillis': event.startsAt.millisecondsSinceEpoch,
      'endsAtMillis': event.endsAt.millisecondsSinceEpoch,
    });
  });

  test('não chama Android com calendário fora da seleção', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls += 1;
          return null;
        });
    final AndroidCalendarEventDraft event = AndroidCalendarEventDraft(
      calendarId: '42',
      title: 'Consulta no dentista',
      startsAt: now.add(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
      previewDigest: 'digest-calendar-123',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    await expectLater(
      gateway.writeConfirmedEvent(
        authorizedCalendarIds: <String>{'99'},
        kind: AndroidCalendarExternalWriteKind.create,
        event: event,
        confirmation: AndroidCalendarWriteConfirmation(
          kind: AndroidCalendarExternalWriteKind.create,
          calendarId: '42',
          eventDigest: 'digest-calendar-123',
          confirmedAt: DateTime.now().toUtc(),
        ),
      ),
      throwsA(isA<AndroidCalendarConfirmationRequiredException>()),
    );
    expect(calls, 0);
  });

  test(
    'consulta envia somente calendários autorizados e intervalo UTC',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            received = call;
            return <Object?>[
              <String, Object?>{
                'id': '7',
                'calendarId': '42',
                'title': 'Consulta',
                'startsAtMillis': now.millisecondsSinceEpoch,
                'endsAtMillis': now
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
              },
            ];
          });

      final List<AndroidCalendarEventPreview> events = await gateway
          .readAuthorizedEvents(
            authorizedCalendarIds: <String>{'42'},
            startsAt: now,
            endsAt: now.add(const Duration(days: 1)),
          );

      expect(received?.method, 'readAuthorizedEvents');
      expect(received?.arguments, <String, Object>{
        'calendarIds': <String>['42'],
        'startsAtMillis': now.millisecondsSinceEpoch,
        'endsAtMillis': now.add(const Duration(days: 1)).millisecondsSinceEpoch,
      });
      expect(events.single.title, 'Consulta');
    },
  );
}
