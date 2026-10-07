import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste somente o modo de tratamento e um apelido opcional no aparelho.
/// A chave é isolada pela conta, seguindo os demais repositórios locais.
final class SharedPreferencesAssistantPersonalizationRepository
    implements AssistantPersonalizationRepository {
  const SharedPreferencesAssistantPersonalizationRepository(this._preferences);

  static const String _keyPrefix = 'assistant_personalization_v1_';
  final SharedPreferences _preferences;

  @override
  Future<AssistantPersonalization> readOwn({required String ownerId}) async {
    _validateOwner(ownerId);
    final String? mode = _preferences.getString('${_key(ownerId)}.mode');
    return switch (mode) {
      'none' => const AssistantPersonalization.none(),
      'customName' => AssistantPersonalization(
        mode: AssistantAddressMode.customName,
        customName: _preferences.getString('${_key(ownerId)}.customName'),
      ),
      _ => const AssistantPersonalization.profileFirstName(),
    };
  }

  @override
  Future<void> saveOwn({
    required String ownerId,
    required AssistantPersonalization personalization,
  }) async {
    _validateOwner(ownerId);
    final String key = _key(ownerId);
    final bool modeSaved = await _preferences.setString(
      '$key.mode',
      personalization.mode.name,
    );
    final bool nameSaved = personalization.customName == null
        ? await _preferences.remove('$key.customName')
        : await _preferences.setString(
            '$key.customName',
            personalization.customName!,
          );
    if (!modeSaved || !nameSaved) {
      throw const AssistantPersonalizationStorageFailure();
    }
  }

  String _key(String ownerId) => '$_keyPrefix$ownerId';

  void _validateOwner(String ownerId) {
    if (ownerId.isEmpty || ownerId.length > 150 || ownerId.contains('/')) {
      throw const AssistantPersonalizationStorageFailure();
    }
  }
}

final class AssistantPersonalizationStorageFailure implements Exception {
  const AssistantPersonalizationStorageFailure();
}
