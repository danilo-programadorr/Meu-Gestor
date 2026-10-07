import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/shared_preferences_assistant_personalization_repository.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<Future<AssistantPersonalizationRepository>>
assistantPersonalizationRepositoryProvider =
    Provider<Future<AssistantPersonalizationRepository>>(
      (Ref ref) async => SharedPreferencesAssistantPersonalizationRepository(
        await SharedPreferences.getInstance(),
      ),
    );

final AsyncNotifierProvider<
  AssistantPersonalizationController,
  AssistantPersonalization
>
assistantPersonalizationControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AssistantPersonalizationController,
      AssistantPersonalization
    >(AssistantPersonalizationController.new);

final class AssistantPersonalizationController
    extends AsyncNotifier<AssistantPersonalization> {
  @override
  Future<AssistantPersonalization> build() async {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) {
      return const AssistantPersonalization.none();
    }
    final AssistantPersonalizationRepository repository = await ref.watch(
      assistantPersonalizationRepositoryProvider,
    );
    return repository.readOwn(ownerId: gate.profile.ownerId);
  }

  Future<void> select(AssistantPersonalization personalization) async {
    final ProfileGateState? gate = ref
        .read(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) return;
    final AssistantPersonalization previous =
        state.value ?? const AssistantPersonalization.profileFirstName();
    state = AsyncData<AssistantPersonalization>(personalization);
    try {
      final AssistantPersonalizationRepository repository = await ref.read(
        assistantPersonalizationRepositoryProvider,
      );
      await repository.saveOwn(
        ownerId: gate.profile.ownerId,
        personalization: personalization,
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<AssistantPersonalization>(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
