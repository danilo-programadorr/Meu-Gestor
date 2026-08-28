import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/android_calendar_selection_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesAndroidCalendarSelectionRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = SharedPreferencesAndroidCalendarSelectionRepository(
      await SharedPreferences.getInstance(),
    );
  });

  test(
    'persiste somente IDs selecionados e separa seleções por usuário',
    () async {
      await repository.saveOwn(
        ownerId: 'owner-a',
        calendarIds: <String>{'1', 'work-calendar'},
      );
      await repository.saveOwn(ownerId: 'owner-b', calendarIds: <String>{'2'});

      expect(await repository.readOwn(ownerId: 'owner-a'), <String>{
        '1',
        'work-calendar',
      });
      expect(await repository.readOwn(ownerId: 'owner-b'), <String>{'2'});
    },
  );

  test('recusa seleção ou namespace inválido', () async {
    await expectLater(
      repository.saveOwn(
        ownerId: 'owner-a',
        calendarIds: <String>{'calendar\u0000invalid'},
      ),
      throwsA(isA<AndroidCalendarSelectionFailure>()),
    );
    await expectLater(
      repository.readOwn(ownerId: 'owner/a'),
      throwsA(isA<AndroidCalendarSelectionFailure>()),
    );
  });
}
