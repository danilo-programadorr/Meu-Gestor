import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference_selector.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class ProfileAppearancePage extends StatelessWidget {
  const ProfileAppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePageShell(
      title: 'Aparência',
      children: <Widget>[
        Text(
          'Escolha o tema mais confortável para usar o aplicativo.',
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.lg),
        AppThemePreferenceSelector(),
      ],
    );
  }
}
