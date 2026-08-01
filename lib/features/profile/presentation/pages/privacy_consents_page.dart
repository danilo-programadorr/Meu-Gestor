import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
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

  Future<void> _save() async {
    await ref
        .read(profileActionControllerProvider.notifier)
        .updateOptionalConsents(
          aiConsentEnabled: _aiConsent ?? false,
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
    _aiConsent ??= profile.aiConsentEnabled;
    _analyticsConsent ??= profile.analyticsConsentEnabled;

    final ProfileActionState action = ref.watch(
      profileActionControllerProvider,
    );
    final bool loading = action.isLoading;
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
          title: const Text('Análises com IA'),
          subtitle: const Text(
            'A IA ainda não está ativa. Alterar esta preferência não chama Gemini nem envia dados.',
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
}
