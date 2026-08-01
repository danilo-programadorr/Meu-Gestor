import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _aiConsent = false;
  bool _analyticsConsent = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(authRepositoryProvider).currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(profileActionControllerProvider.notifier)
        .createProfile(
          displayName: _nameController.text,
          termsAccepted: _acceptedTerms,
          privacyAccepted: _acceptedPrivacy,
          aiConsentEnabled: _aiConsent,
          analyticsConsentEnabled: _analyticsConsent,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading;
    return ProfilePageShell(
      title: 'Configuração inicial',
      children: <Widget>[
        Icon(
          Icons.manage_accounts_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: 'Configuração segura do perfil',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Complete seu perfil',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Antes de acessar a área autenticada, confirme seu nome e suas escolhas de privacidade.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            enabled: !loading,
            decoration: const InputDecoration(
              labelText: 'Nome',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.name],
            validator: DisplayName.validate,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Card(
          child: Column(
            children: <Widget>[
              ProfileInfoTile(
                label: 'Idioma',
                value: UserProfile.supportedLocale,
                icon: Icons.language_outlined,
              ),
              ProfileInfoTile(
                label: 'Moeda',
                value: UserProfile.supportedCurrencyCode,
                icon: Icons.payments_outlined,
              ),
              ProfileInfoTile(
                label: 'Fuso horário',
                value: UserProfile.supportedTimeZone,
                icon: Icons.schedule_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _RequiredConsent(
          value: _acceptedTerms,
          label: 'Li e aceito os Termos de Uso provisórios',
          enabled: !loading,
          onChanged: (bool value) => setState(() => _acceptedTerms = value),
          onOpen: () => context.push(AppRoutes.terms),
        ),
        _RequiredConsent(
          value: _acceptedPrivacy,
          label: 'Li e aceito a Política de Privacidade provisória',
          enabled: !loading,
          onChanged: (bool value) => setState(() => _acceptedPrivacy = value),
          onOpen: () => context.push(AppRoutes.privacy),
        ),
        const Divider(),
        SwitchListTile(
          value: _aiConsent,
          onChanged: loading
              ? null
              : (bool value) => setState(() => _aiConsent = value),
          title: const Text('Permitir análises com IA futuramente'),
          subtitle: const Text(
            'Opcional e desativado por padrão. A IA ainda não está ativa e esta escolha não envia dados.',
          ),
        ),
        SwitchListTile(
          value: _analyticsConsent,
          onChanged: loading
              ? null
              : (bool value) => setState(() => _analyticsConsent = value),
          title: const Text('Permitir Analytics futuramente'),
          subtitle: const Text(
            'Opcional e separado da IA. Analytics ainda não está ativo e nenhum evento será enviado.',
          ),
        ),
        if (action.message case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ProfileMessage(
            message: message,
            isError: action.status == ProfileActionStatus.failure,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          button: true,
          label: 'Continuar e criar perfil',
          child: FilledButton.icon(
            onPressed: loading ? null : _submit,
            icon: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continuar'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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

class _RequiredConsent extends StatelessWidget {
  const _RequiredConsent({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: <Widget>[
              CheckboxListTile(
                value: value,
                onChanged: enabled
                    ? (bool? selected) => onChanged(selected ?? false)
                    : null,
                title: Text(label),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: enabled ? onOpen : null,
                  child: const Text('Ler documento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
