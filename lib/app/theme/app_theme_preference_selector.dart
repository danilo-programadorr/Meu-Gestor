import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';

class AppThemePreferenceSelector extends ConsumerWidget {
  const AppThemePreferenceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemePreference selected = ref.watch(
      appThemePreferenceControllerProvider,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            'Aparência',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Escolha como o aplicativo acompanha a iluminação da sua tela.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < AppThemePreference.values.length;
                index++
              ) ...<Widget>[
                _ThemePreferenceTile(
                  preference: AppThemePreference.values[index],
                  selected: selected == AppThemePreference.values[index],
                  onTap: () =>
                      _select(context, ref, AppThemePreference.values[index]),
                ),
                if (index < AppThemePreference.values.length - 1)
                  const Divider(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference preference,
  ) async {
    try {
      await ref
          .read(appThemePreferenceControllerProvider.notifier)
          .select(preference);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a aparência. Tente novamente.',
            ),
          ),
        );
      }
    }
  }
}

class _ThemePreferenceTile extends StatelessWidget {
  const _ThemePreferenceTile({
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreference preference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Tema ${preference.label}${selected ? ', selecionado' : ''}',
    child: ListTile(
      minTileHeight: 64,
      leading: Icon(preference.icon, semanticLabel: preference.label),
      title: Text(preference.label),
      subtitle: preference == AppThemePreference.system
          ? const Text('Acompanha a configuração do aparelho')
          : null,
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, semanticLabel: 'Selecionado')
          : const Icon(Icons.circle_outlined, semanticLabel: 'Não selecionado'),
      selected: selected,
      onTap: onTap,
    ),
  );
}
