import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_consent_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_action_state.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class PrivacyConsentsPage extends ConsumerStatefulWidget {
  const PrivacyConsentsPage({super.key});

  @override
  ConsumerState<PrivacyConsentsPage> createState() =>
      _PrivacyConsentsPageState();
}

class _PrivacyConsentsPageState extends ConsumerState<PrivacyConsentsPage> {
  bool? _analyticsConsent;
  bool _revokingAssistantConsent = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref
            .read(assistantRemoteConsentControllerProvider.notifier)
            .load();
      } on Object {
        // A ausência ou uma falha de leitura preserva o estado fechado.
      }
    });
  }

  Future<void> _saveAnalyticsPreference() async {
    final ProfileGateState? gate = ref
        .read(profileGateControllerProvider)
        .value;
    if (gate is! ProfileGateValid) return;
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateOptionalConsents(
          aiConsentEnabled: gate.profile.aiConsentEnabled,
          analyticsConsentEnabled: _analyticsConsent ?? false,
        );
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
    _analyticsConsent ??= profile.analyticsConsentEnabled;

    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading;
    final bool remoteConsentAllowed = ref.watch(
      assistantRemoteConsentControllerProvider,
    );
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

    return ProfilePageShell(
      title: 'Privacidade e consentimentos',
      children: <Widget>[
        Text(
          'Documentos obrigatórios',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: <Widget>[
              ProfileInfoTile(
                label: 'Termos de Uso aceitos',
                value:
                    '${profile.termsVersionAccepted} em ${dateFormat.format(profile.termsAcceptedAt.toLocal())}',
                icon: Icons.description_outlined,
              ),
              ProfileInfoTile(
                label: 'Política de Privacidade aceita',
                value:
                    '${profile.privacyVersionAccepted} em ${dateFormat.format(profile.privacyAcceptedAt.toLocal())}',
                icon: Icons.policy_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Preferências opcionais',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AssistantConsentRevocationCard(
          enabled: profile.aiConsentEnabled || remoteConsentAllowed,
          loading: loading || _revokingAssistantConsent,
          onRevoke: _revokeAssistantConsent,
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          value: _analyticsConsent!,
          onChanged: loading
              ? null
              : (bool value) => setState(() => _analyticsConsent = value),
          title: const Text('Analytics'),
          subtitle: const Text(
            'Analytics ainda não está ativo. Alterar esta preferência não instala o serviço nem envia eventos.',
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
          label: 'Salvar preferência de Analytics',
          child: FilledButton.icon(
            onPressed: loading || _revokingAssistantConsent
                ? null
                : _saveAnalyticsPreference,
            icon: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salvar preferência de Analytics'),
          ),
        ),
      ],
    );
  }

  Future<void> _revokeAssistantConsent() async {
    setState(() => _revokingAssistantConsent = true);
    try {
      final ProfileGateState? gate = ref
          .read(profileGateControllerProvider)
          .value;
      if (gate is! ProfileGateValid) return;
      await ref
          .read(profileActionControllerProvider.notifier)
          .updateOptionalConsents(
            aiConsentEnabled: false,
            analyticsConsentEnabled: _analyticsConsent ?? false,
          );
      if (ref.read(profileActionControllerProvider).status !=
          ProfileActionStatus.success) {
        return;
      }
      await ref
          .read(assistantRemoteConsentControllerProvider.notifier)
          .setAllowed(false);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a permissão remota.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingAssistantConsent = false);
    }
  }
}

class _AssistantConsentRevocationCard extends StatelessWidget {
  const _AssistantConsentRevocationCard({
    required this.enabled,
    required this.loading,
    required this.onRevoke,
  });

  final bool enabled;
  final bool loading;
  final Future<void> Function() onRevoke;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Assistente Financeiro',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            enabled
                ? 'O consentimento pode ser revogado a qualquer momento. A revogação bloqueia imediatamente novas chamadas remotas.'
                : 'O Assistente Financeiro está desativado. Para ativá-lo, abra uma conversa e escolha “Ativar e continuar”.',
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: loading ? null : () => onRevoke(),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Revogar consentimento do Assistente'),
            ),
          ],
        ],
      ),
    ),
  );
}
