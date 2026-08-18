import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/privacy_operation_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class DataAndPrivacyPage extends ConsumerWidget {
  const DataAndPrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrivacyUiState state = ref.watch(privacyOperationControllerProvider);
    return ProfilePageShell(
      title: 'Dados e privacidade',
      children: <Widget>[
        const Text(
          'Você controla seus dados financeiros e sua conta.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ActionCard(
          type: PrivacyOperationType.financialReset,
          icon: Icons.restart_alt_outlined,
          title: 'Resetar dados financeiros',
          description:
              'Remove contas, categorias, lançamentos, compromissos e investimentos. Mantém perfil, consentimentos, aparência, Premium e acesso proprietário.',
          onTap: state.isBusy
              ? null
              : () => _showConfirmation(
                  context,
                  ref,
                  PrivacyOperationType.financialReset,
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionCard(
          type: PrivacyOperationType.accountDeletion,
          icon: Icons.delete_forever_outlined,
          title: 'Excluir permanentemente minha conta',
          description:
              'Remove dados vinculados, perfil e acesso. Esta ação não cancela sua assinatura Google Play.',
          destructive: true,
          onTap: state.isBusy
              ? null
              : () => _showConfirmation(
                  context,
                  ref,
                  PrivacyOperationType.accountDeletion,
                ),
        ),
        if (state.message case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
        if (state.isBusy) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  Future<void> _showConfirmation(
    BuildContext context,
    WidgetRef ref,
    PrivacyOperationType type,
  ) async {
    ref.read(privacyOperationControllerProvider.notifier).prepare(type);
    final TextEditingController phrase = TextEditingController();
    final TextEditingController password = TextEditingController();
    PrivacyReauthenticationMethod method =
        PrivacyReauthenticationMethod.password;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text(
            type == PrivacyOperationType.financialReset
                ? 'Confirmar reset financeiro'
                : 'Confirmar exclusão da conta',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Digite: ${type.confirmationPhrase}'),
                TextField(
                  controller: phrase,
                  decoration: const InputDecoration(
                    labelText: 'Frase de confirmação',
                  ),
                ),
                DropdownButton<PrivacyReauthenticationMethod>(
                  value: method,
                  isExpanded: true,
                  items:
                      const <DropdownMenuItem<PrivacyReauthenticationMethod>>[
                        DropdownMenuItem(
                          value: PrivacyReauthenticationMethod.password,
                          child: Text('Confirmar com senha'),
                        ),
                        DropdownMenuItem(
                          value: PrivacyReauthenticationMethod.google,
                          child: Text('Confirmar com Google'),
                        ),
                      ],
                  onChanged: (PrivacyReauthenticationMethod? value) {
                    if (value != null) setState(() => method = value);
                  },
                ),
                if (method == PrivacyReauthenticationMethod.password)
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha atual'),
                  ),
                if (type == PrivacyOperationType.accountDeletion)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Excluir a conta não cancela a assinatura Google Play. Gerencie-a pela Play Store quando aplicável.',
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(privacyOperationControllerProvider.notifier)
                    .submit(
                      type: type,
                      phrase: phrase.text,
                      method: method,
                      password: password.text,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    phrase.dispose();
    password.dispose();
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.type,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });
  final PrivacyOperationType type;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            color: destructive ? Theme.of(context).colorScheme.error : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(description),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(onPressed: onTap, child: Text('Continuar')),
          ),
        ],
      ),
    ),
  );
}
