import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/widgets/assistant_personalization_selector.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class ProfileAssistantPage extends ConsumerWidget {
  const ProfileAssistantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    if (gate case ProfileGateValid(:final profile)) {
      return ProfilePageShell(
        title: 'Personalização da Luma',
        children: <Widget>[
          const Text(
            'Defina como a Luma pode se dirigir a você durante as conversas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AssistantPersonalizationSelector(profile: profile),
        ],
      );
    }
    return const ProfilePageShell(
      title: 'Personalização da Luma',
      children: <Widget>[
        Center(child: CircularProgressIndicator()),
        SizedBox(height: AppSpacing.md),
        Text('Carregando suas preferências...', textAlign: TextAlign.center),
      ],
    );
  }
}
