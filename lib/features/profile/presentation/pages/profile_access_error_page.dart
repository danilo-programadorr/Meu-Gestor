import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/widgets/profile_page_shell.dart';

class ProfileAccessErrorPage extends ConsumerWidget {
  const ProfileAccessErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileGateState> gate = ref.watch(
      profileGateControllerProvider,
    );
    final ProfileGateState? value = gate.value;
    final bool tokenPending = value is ProfileGateUnverifiedEmail;
    final UserProfileFailure? failure = switch (value) {
      ProfileGateFailure(:final failure) => failure,
      ProfileGateIncompatible(:final failure) => failure,
      _ => null,
    };
    final String message = switch (value) {
      ProfileGateFailure(:final failure) => failure.safeMessage,
      ProfileGateIncompatible(:final failure) => failure.safeMessage,
      ProfileGateUnverifiedEmail() =>
        'A confirmação do email ainda não chegou ao token de segurança. Atualize e tente novamente.',
      _ => 'Não foi possível verificar seu perfil. Tente novamente.',
    };
    final bool loading = gate.isLoading || value is ProfileGateProgress;
    final bool isDevelopment =
        ref.watch(appEnvironmentProvider) == AppEnvironment.development;
    final String? safeCode = isDevelopment ? failure?.code : null;
    final AuthActionState authAction = ref.watch(authControllerProvider);

    return ProfilePageShell(
      title: tokenPending ? 'Atualizar confirmação' : 'Perfil indisponível',
      children: <Widget>[
        Icon(
          tokenPending ? Icons.sync_lock_outlined : Icons.shield_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: tokenPending
              ? 'Token de confirmação pendente'
              : 'Acesso ao perfil protegido',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (safeCode != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            safeCode,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: loading
              ? null
              : ref.read(profileGateControllerProvider.notifier).retry,
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () => context.push(AppRoutes.terms),
              child: const Text('Termos de Uso'),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.privacy),
              child: const Text('Política de Privacidade'),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: authAction.isLoading
              ? null
              : ref.read(authControllerProvider.notifier).signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
        ),
      ],
    );
  }
}
