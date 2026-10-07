import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_personalization_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';

class AssistantPersonalizationSelector extends ConsumerWidget {
  const AssistantPersonalizationSelector({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AssistantPersonalization> value = ref.watch(
      assistantPersonalizationControllerProvider,
    );
    final AssistantPersonalization? selected = value.value;
    final String firstName = AssistantPersonalization.firstName(
      profile.displayName,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            AssistantPersonalization.assistantName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Escolha como a Luma pode chamar você nas saudações. Essa preferência fica somente neste aparelho.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: <Widget>[
              _AddressTile(
                title: firstName.isEmpty
                    ? 'Usar nome do perfil'
                    : 'Usar $firstName',
                subtitle: 'Usa somente o primeiro nome confirmado no perfil',
                selected:
                    selected?.mode == AssistantAddressMode.profileFirstName,
                enabled: !value.isLoading,
                onTap: () => _save(
                  context,
                  ref,
                  const AssistantPersonalization.profileFirstName(),
                ),
              ),
              const Divider(),
              _AddressTile(
                title: 'Usar apelido',
                subtitle: selected?.mode == AssistantAddressMode.customName
                    ? selected!.customName!
                    : 'Escolher um nome ou apelido',
                selected: selected?.mode == AssistantAddressMode.customName,
                enabled: !value.isLoading,
                onTap: () =>
                    unawaited(_chooseCustomName(context, ref, selected)),
              ),
              const Divider(),
              _AddressTile(
                title: 'Não usar meu nome',
                subtitle: 'A Luma conversa sem tratamento pessoal',
                selected: selected?.mode == AssistantAddressMode.none,
                enabled: !value.isLoading,
                onTap: () =>
                    _save(context, ref, const AssistantPersonalization.none()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _chooseCustomName(
    BuildContext context,
    WidgetRef ref,
    AssistantPersonalization? selected,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: selected?.customName ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final String? customName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Como a Luma chama você?'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: AssistantPersonalization.maximumAddressLength,
            decoration: const InputDecoration(labelText: 'Nome ou apelido'),
            validator: AssistantPersonalization.validateAddressName,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext).pop(controller.text);
              }
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext).pop(controller.text);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (customName == null || !context.mounted) return;
    await _save(
      context,
      ref,
      AssistantPersonalization(
        mode: AssistantAddressMode.customName,
        customName: AssistantPersonalization.requireValidAddressName(
          customName,
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AssistantPersonalization personalization,
  ) async {
    try {
      await ref
          .read(assistantPersonalizationControllerProvider.notifier)
          .select(personalization);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar essa preferência.'),
          ),
        );
      }
    }
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    enabled: enabled,
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: selected
        ? const Icon(Icons.check_circle_rounded, semanticLabel: 'Selecionado')
        : const Icon(Icons.circle_outlined, semanticLabel: 'Não selecionado'),
    selected: selected,
    onTap: enabled ? onTap : null,
  );
}
