import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference_selector.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/widgets/owner_access_badge.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _editing = false;
  String? _loadedName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateDisplayName(_nameController.text);
    if (mounted &&
        ref.read(profileActionControllerProvider).status ==
            ProfileActionStatus.success) {
      setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    final UserProfile? profile = gate is ProfileGateValid ? gate.profile : null;
    if (profile == null) {
      return const SizedBox.shrink();
    }
    if (_loadedName != profile.displayName) {
      _loadedName = profile.displayName;
      _nameController.text = profile.displayName;
    }

    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading;
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final bool hasOwnerAccess = ref.watch(
      masterAccessControllerProvider.select((state) => state.isActiveOwner),
    );

    return ProfilePageShell(
      title: 'Perfil',
      children: <Widget>[
        Icon(
          Icons.account_circle_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: 'Perfil do usuário',
        ),
        const SizedBox(height: AppSpacing.md),
        if (_editing)
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameController,
              enabled: !loading,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: DisplayName.validate,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveName(),
            ),
          )
        else
          Semantics(
            header: true,
            child: Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (hasOwnerAccess) ...<Widget>[
          const Center(child: OwnerAccessBadge()),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_editing)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton(
                onPressed: loading ? null : _saveName,
                child: const Text('Salvar nome'),
              ),
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        _nameController.text = profile.displayName;
                        setState(() => _editing = false);
                      },
                child: const Text('Cancelar'),
              ),
            ],
          )
        else
          Center(
            child: OutlinedButton.icon(
              onPressed: loading ? null : () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar nome'),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: <Widget>[
              ProfileInfoTile(
                label: 'Idioma',
                value: profile.locale,
                icon: Icons.language_outlined,
              ),
              ProfileInfoTile(
                label: 'Moeda',
                value: profile.currencyCode,
                icon: Icons.payments_outlined,
              ),
              ProfileInfoTile(
                label: 'Fuso horário',
                value: profile.timeZone,
                icon: Icons.schedule_outlined,
              ),
              ProfileInfoTile(
                label: 'Email',
                value: profile.emailVerifiedSnapshot
                    ? 'Confirmado'
                    : 'Confirmação pendente',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
        ),
        if (environment == AppEnvironment.development) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const Center(child: Chip(label: Text('Ambiente de desenvolvimento'))),
        ],
        const SizedBox(height: AppSpacing.lg),
        const AppThemePreferenceSelector(),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: loading ? null : () => context.push(AppRoutes.premium),
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const Text('Premium e assinatura'),
        ),
        if (action.message case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ProfileMessage(
            message: message,
            isError:
                action.status == ProfileActionStatus.failure ||
                action.hasPartialFailure,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: loading
              ? null
              : () => context.push(AppRoutes.privacyConsents),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: const Text('Privacidade e consentimentos'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () => context.push(AppRoutes.dataAndPrivacy),
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Dados e privacidade'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: loading ? null : () => context.go(AppRoutes.home),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Voltar ao início'),
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
