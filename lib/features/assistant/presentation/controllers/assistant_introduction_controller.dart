import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/shared_preferences_assistant_introduction_repository.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_introduction.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<Future<AssistantIntroductionRepository>>
assistantIntroductionRepositoryProvider =
    Provider<Future<AssistantIntroductionRepository>>(
      (Ref ref) async => SharedPreferencesAssistantIntroductionRepository(
        await SharedPreferences.getInstance(),
      ),
    );

final AsyncNotifierProvider<AssistantIntroductionController, bool>
assistantIntroductionControllerProvider =
    AsyncNotifierProvider.autoDispose<AssistantIntroductionController, bool>(
      AssistantIntroductionController.new,
    );

final class AssistantIntroductionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) return true;
    final AssistantIntroductionRepository repository = await ref.watch(
      assistantIntroductionRepositoryProvider,
    );
    return repository.hasSeen(ownerId: gate.profile.ownerId);
  }

  Future<void> markSeen() async {
    final ProfileGateState? gate = ref
        .read(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) return;
    final bool previous = state.value ?? false;
    try {
      final AssistantIntroductionRepository repository = await ref.read(
        assistantIntroductionRepositoryProvider,
      );
      await repository.markSeen(ownerId: gate.profile.ownerId);
      state = const AsyncData<bool>(true);
    } on Object catch (error, stackTrace) {
      state = AsyncData<bool>(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
