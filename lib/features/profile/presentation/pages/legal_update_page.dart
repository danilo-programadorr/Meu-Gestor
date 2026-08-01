import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class LegalUpdatePage extends ConsumerStatefulWidget {
  const LegalUpdatePage({super.key});

  @override
  ConsumerState<LegalUpdatePage> createState() => _LegalUpdatePageState();
}

class _LegalUpdatePageState extends ConsumerState<LegalUpdatePage> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  Future<void> _submit() async {
    await ref
        .read(profileActionControllerProvider.notifier)
        .acceptCurrentLegalVersions(
          termsAccepted: _acceptedTerms,
          privacyAccepted: _acceptedPrivacy,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading;
    return ProfilePageShell(
      title: 'Atualização de documentos',
      children: <Widget>[
        Icon(
          Icons.fact_check_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: 'Nova confirmação jurídica necessária',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Revise as versões atuais',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Os documentos continuam provisórios e exclusivos do ambiente de desenvolvimento.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: loading
              ? null
              : (bool? value) =>
                    setState(() => _acceptedTerms = value ?? false),
          title: const Text(
            'Li e aceito os Termos de Uso ${LegalDocumentVersions.terms}',
          ),
          subtitle: TextButton(
            onPressed: loading ? null : () => context.push(AppRoutes.terms),
            child: const Text('Ler Termos de Uso'),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _acceptedPrivacy,
          onChanged: loading
              ? null
              : (bool? value) =>
                    setState(() => _acceptedPrivacy = value ?? false),
          title: const Text(
            'Li e aceito a Política de Privacidade ${LegalDocumentVersions.privacy}',
          ),
          subtitle: TextButton(
            onPressed: loading ? null : () => context.push(AppRoutes.privacy),
            child: const Text('Ler Política de Privacidade'),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (action.message case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ProfileMessage(
            message: message,
            isError: action.status == ProfileActionStatus.failure,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: loading ? null : _submit,
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Confirmar novas versões'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: loading
              ? null
              : ref.read(authControllerProvider.notifier).signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
        ),
      ],
    );
  }
}
