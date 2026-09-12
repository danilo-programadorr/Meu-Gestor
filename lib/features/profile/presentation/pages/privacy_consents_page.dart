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
  bool? _aiConsent;
  bool? _analyticsConsent;
  bool _updatingRemoteConsent = false;

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

  Future<void> _save() async {
    final bool aiConsentEnabled = _aiConsent ?? false;
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateOptionalConsents(
          aiConsentEnabled: aiConsentEnabled,
          analyticsConsentEnabled: _analyticsConsent ?? false,
        );
    if (!aiConsentEnabled &&
        ref.read(profileActionControllerProvider).status ==
            ProfileActionStatus.success &&
        ref.read(assistantRemoteConsentControllerProvider)) {
      await _setRemoteConsent(false);
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
    _aiConsent ??= profile.aiConsentEnabled;
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
        SwitchListTile(
          value: _aiConsent!,
          onChanged: loading
              ? null
              : (bool value) => setState(() => _aiConsent = value),
          title: const Text('Assistente e análises com IA'),
          subtitle: const Text(
            'Controla o acesso ao Assistente. O envio de uma pergunta também exige a permissão separada para contexto financeiro remoto.',
          ),
        ),
        SwitchListTile(
          value: remoteConsentAllowed,
          onChanged:
              loading || _updatingRemoteConsent || !profile.aiConsentEnabled
              ? null
              : _setRemoteConsent,
          title: const Text('Permitir contexto financeiro remoto'),
          subtitle: Text(
            profile.aiConsentEnabled
                ? 'Permissão separada e revogável. Sem ela, o backend trata a privacidade financeira como ativa e bloqueia qualquer chamada remota.'
                : 'Salve primeiro o consentimento do Assistente. O contexto remoto permanece bloqueado.',
          ),
        ),
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
          label: 'Salvar preferências de privacidade',
          child: FilledButton.icon(
            onPressed: loading ? null : _save,
            icon: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salvar preferências'),
          ),
        ),
      ],
    );
  }

  Future<void> _setRemoteConsent(bool value) async {
    setState(() => _updatingRemoteConsent = true);
    try {
      await ref
          .read(assistantRemoteConsentControllerProvider.notifier)
          .setAllowed(value);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a permissão remota.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingRemoteConsent = false);
    }
  }
}
