import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_personalization_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/email_masker.dart';
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
  bool _signingOut = false;
  String? _loadedName;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(profileActionControllerProvider.notifier).clearMessage(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateDisplayName(_nameController.text);
    if (mounted &&
        ref.read(profileActionControllerProvider).status ==
            ProfileActionStatus.success) {
      setState(() => _editing = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Sair da conta?'),
            content: const Text(
              'Você precisará entrar novamente para acessar seus dados.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    final UserProfile? profile = gate is ProfileGateValid ? gate.profile : null;
    if (profile == null) {
      return const ProfilePageShell(
        title: 'Perfil',
        children: <Widget>[
          Center(child: CircularProgressIndicator()),
          SizedBox(height: AppSpacing.md),
          Text('Carregando seu perfil...', textAlign: TextAlign.center),
        ],
      );
    }
    if (_loadedName != profile.displayName) {
      _loadedName = profile.displayName;
      _nameController.text = profile.displayName;
    }

    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading || _signingOut;
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final bool hasOwnerAccess = ref.watch(
      masterAccessControllerProvider.select((state) => state.isActiveOwner),
    );
    final AuthUser? user = ref.watch(authStateProvider).value;
    final AppThemePreference theme = ref.watch(
      appThemePreferenceControllerProvider,
    );
    final AsyncValue<AssistantPersonalization> personalization = ref.watch(
      assistantPersonalizationControllerProvider,
    );

    return ProfilePageShell(
      title: 'Perfil',
      children: <Widget>[
        _ProfileHeader(
          profile: profile,
          maskedEmail: EmailMasker.mask(user?.email),
          hasOwnerAccess: hasOwnerAccess,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_editing)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  enabled: !loading,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: DisplayName.validate,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveName(),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                ),
              ],
            ),
          )
        else
          Center(
            child: OutlinedButton.icon(
              onPressed: loading ? null : () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar nome'),
            ),
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
        const SizedBox(height: AppSpacing.xl),
        const _SectionTitle('Preferências'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: <Widget>[
              _ProfileDestinationTile(
                icon: theme.icon,
                title: 'Aparência',
                subtitle: 'Tema ${theme.label.toLowerCase()}',
                onTap: loading
                    ? null
                    : () => context.push(AppRoutes.profileAppearance),
              ),
              const Divider(),
              _ProfileDestinationTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Personalização da Luma',
                subtitle: _personalizationSummary(personalization, profile),
                onTap: loading
                    ? null
                    : () => context.push(AppRoutes.profileAssistant),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle('Privacidade e dados'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: <Widget>[
              _ProfileDestinationTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacidade e consentimentos',
                subtitle: 'Assistente, Analytics e documentos aceitos',
                onTap: loading
                    ? null
                    : () => context.push(AppRoutes.privacyConsents),
              ),
              const Divider(),
              _ProfileDestinationTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Dados da conta',
                subtitle: 'Reset financeiro e exclusão da conta',
                onTap: loading
                    ? null
                    : () => context.push(AppRoutes.dataAndPrivacy),
              ),
            ],
          ),
        ),
        if (environment == AppEnvironment.development) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: Chip(label: Text('Ambiente de desenvolvimento'))),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextButton.icon(
          onPressed: loading ? null : _confirmSignOut,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: _signingOut
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
        ),
      ],
    );
  }

  static String _personalizationSummary(
    AsyncValue<AssistantPersonalization> value,
    UserProfile profile,
  ) {
    final AssistantPersonalization? selected = value.value;
    if (selected == null) return 'Carregando preferência...';
    return switch (selected.mode) {
      AssistantAddressMode.profileFirstName =>
        'Luma chama você de ${AssistantPersonalization.firstName(profile.displayName)}',
      AssistantAddressMode.customName =>
        'Luma chama você de ${selected.customName}',
      AssistantAddressMode.none => 'Luma conversa sem usar seu nome',
    };
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.maskedEmail,
    required this.hasOwnerAccess,
  });

  final UserProfile profile;
  final String maskedEmail;
  final bool hasOwnerAccess;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 38,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              _initials(profile.displayName),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
              semanticsLabel: 'Iniciais do perfil',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(maskedEmail, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Chip(
                avatar: Icon(Icons.verified_outlined, size: 18),
                label: Text('Email confirmado'),
              ),
              Chip(label: Text('Português • Real • Brasília')),
            ],
          ),
          if (hasOwnerAccess) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const OwnerAccessBadge(),
          ],
        ],
      ),
    ),
  );

  static String _initials(String displayName) {
    final List<String> words = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    final String first = words.first.characters.first;
    final String last = words.length > 1 ? words.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(label, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _ProfileDestinationTile extends StatelessWidget {
  const _ProfileDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 72,
    enabled: onTap != null,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
