import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/email_masker.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_components.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_scaffold.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  static const int _cooldownSeconds = 60;
  Timer? _cooldownTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_remainingSeconds > 0) {
      return;
    }
    await ref.read(authControllerProvider.notifier).resendVerification();
    final AuthActionState state = ref.read(authControllerProvider);
    if (state.status != AuthActionStatus.success || !mounted) {
      return;
    }
    setState(() => _remainingSeconds = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _remainingSeconds = 0);
        }
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> authState = ref.watch(authStateProvider);
    final AuthActionState actionState = ref.watch(authControllerProvider);
    final String maskedEmail = EmailMasker.mask(authState.value?.email);
    final bool isLoading = actionState.isLoading;
    final bool resendBlocked = isLoading || _remainingSeconds > 0;

    return AuthScaffold(
      showHero: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthBrand(),
          const SizedBox(height: AppSpacing.xl),
          Icon(
            Icons.mark_email_unread_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
            semanticLabel: 'Email aguardando confirmação',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Confirme seu email',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enviamos uma mensagem para $maskedEmail. Abra o link recebido e '
            'depois atualize o estado aqui.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enquanto a confirmação estiver pendente, dados financeiros não '
            'podem ser acessados ou alterados.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (actionState.message case final String message) ...<Widget>[
            AuthErrorMessage(
              message: message,
              isError: actionState.status == AuthActionStatus.failure,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AuthPrimaryButton(
            label: 'Atualizar confirmação',
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : ref.read(authControllerProvider.notifier).refreshVerification,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: resendBlocked ? null : _resend,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: Text(
              _remainingSeconds > 0
                  ? 'Reenviar em $_remainingSeconds s'
                  : 'Reenviar email de confirmação',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
          const Divider(),
          TextButton.icon(
            onPressed: isLoading
                ? null
                : ref.read(authControllerProvider.notifier).signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
  }
}
