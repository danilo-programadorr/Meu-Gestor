import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_introduction.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mantém a apresentação isolada por conta e somente no aparelho atual.
final class SharedPreferencesAssistantIntroductionRepository
    implements AssistantIntroductionRepository {
  const SharedPreferencesAssistantIntroductionRepository(this._preferences);

  static const String _keyPrefix = 'assistant_introduction_v1_';
  final SharedPreferences _preferences;

  @override
  Future<bool> hasSeen({required String ownerId}) async {
    _validateOwner(ownerId);
    return _preferences.getBool('$_keyPrefix$ownerId') ?? false;
  }

  @override
  Future<void> markSeen({required String ownerId}) async {
    _validateOwner(ownerId);
    if (!await _preferences.setBool('$_keyPrefix$ownerId', true)) {
      throw const AssistantIntroductionStorageFailure();
    }
  }

  void _validateOwner(String ownerId) {
    if (ownerId.isEmpty || ownerId.length > 150 || ownerId.contains('/')) {
      throw const AssistantIntroductionStorageFailure();
    }
  }
}
