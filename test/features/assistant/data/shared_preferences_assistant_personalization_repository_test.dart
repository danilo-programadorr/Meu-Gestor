import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/shared_preferences_assistant_personalization_repository.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preferência local é isolada por conta e começa pelo perfil', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferencesAssistantPersonalizationRepository repository =
        SharedPreferencesAssistantPersonalizationRepository(
          await SharedPreferences.getInstance(),
        );

    expect(
      (await repository.readOwn(ownerId: 'owner-a')).mode,
      AssistantAddressMode.profileFirstName,
    );
    await repository.saveOwn(
      ownerId: 'owner-a',
      personalization: AssistantPersonalization(
        mode: AssistantAddressMode.customName,
        customName: 'Dani',
      ),
    );
    await repository.saveOwn(
      ownerId: 'owner-b',
      personalization: const AssistantPersonalization.none(),
    );

    expect((await repository.readOwn(ownerId: 'owner-a')).customName, 'Dani');
    expect(
      (await repository.readOwn(ownerId: 'owner-b')).mode,
      AssistantAddressMode.none,
    );
  });

  test('conta inválida falha sem compartilhar preferência', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferencesAssistantPersonalizationRepository repository =
        SharedPreferencesAssistantPersonalizationRepository(
          await SharedPreferences.getInstance(),
        );

    expect(
      () => repository.readOwn(ownerId: 'owner/inválido'),
      throwsA(isA<AssistantPersonalizationStorageFailure>()),
    );
  });
}
