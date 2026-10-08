import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/shared_preferences_assistant_introduction_repository.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_introduction.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('apresentação aparece uma vez por conta no aparelho', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferencesAssistantIntroductionRepository repository =
        SharedPreferencesAssistantIntroductionRepository(
          await SharedPreferences.getInstance(),
        );

    expect(await repository.hasSeen(ownerId: 'owner-a'), isFalse);
    expect(await repository.hasSeen(ownerId: 'owner-b'), isFalse);

    await repository.markSeen(ownerId: 'owner-a');

    expect(await repository.hasSeen(ownerId: 'owner-a'), isTrue);
    expect(await repository.hasSeen(ownerId: 'owner-b'), isFalse);
  });

  test('conta inválida não compartilha estado local', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferencesAssistantIntroductionRepository repository =
        SharedPreferencesAssistantIntroductionRepository(
          await SharedPreferences.getInstance(),
        );

    expect(
      () => repository.markSeen(ownerId: 'owner/inválido'),
      throwsA(isA<AssistantIntroductionStorageFailure>()),
    );
  });
}
