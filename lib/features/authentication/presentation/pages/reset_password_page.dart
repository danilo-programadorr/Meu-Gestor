import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_validators.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_components.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_scaffold.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final AuthActionState actionState = ref.watch(authControllerProvider);
    final bool isLoading = actionState.isLoading;
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthBrand(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Redefinir senha',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Informe seu email para receber as instruções de redefinição.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              validator: AuthValidators.email,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              onFieldSubmitted: (_) => _submit(),
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
              label: 'Enviar link de redefinição',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            const AuthDivider(label: 'ou'),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: isLoading ? null : () => context.go(AppRoutes.login),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar para o login'),
            ),
          ],
        ),
      ),
    );
  }
}
