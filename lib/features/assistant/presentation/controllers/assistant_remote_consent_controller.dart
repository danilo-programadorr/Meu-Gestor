import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/firebase_assistant_remote_consent_repository.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_remote_consent.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';

final Provider<AssistantRemoteConsentRepository>
assistantRemoteConsentRepositoryProvider =
    Provider<AssistantRemoteConsentRepository>(
      (Ref ref) => FirebaseAssistantRemoteConsentRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
      ),
    );

final NotifierProvider<AssistantRemoteConsentController, bool>
assistantRemoteConsentControllerProvider =
    NotifierProvider<AssistantRemoteConsentController, bool>(
      AssistantRemoteConsentController.new,
    );

/// Coordena um aceite explícito e permite revogá-lo sem enviar dado financeiro.
final class AssistantRemoteConsentController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Revalida a identidade e lê no servidor; cache ou ausência nunca liberam.
  Future<void> load() async {
    final String ownerId = await _verifiedOwnerId();
    final bool allowed = await ref
        .read(assistantRemoteConsentRepositoryProvider)
        .readOwnConsent(ownerId: ownerId);
    state = allowed;
  }

  Future<void> setAllowed(bool value) async {
    final String ownerId = await _verifiedOwnerId();
    await ref
        .read(assistantRemoteConsentRepositoryProvider)
        .setOwnConsent(ownerId: ownerId, financialContextAllowed: value);
    state = value;
  }

  /// Nunca aceita uma identidade local sem token renovado e e-mail confirmado.
  Future<String> _verifiedOwnerId() async {
    final verification = await ref
        .read(authRepositoryProvider)
        .forceRefreshIdentityToken();
    final String? ownerId = verification.user?.id;
    if (!verification.isFullyVerified || ownerId == null) {
      throw StateError('assistant_remote_consent_identity_unavailable');
    }
    return ownerId;
  }
}
