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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).clearMessage();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthActionState actionState = ref.watch(authControllerProvider);
    final bool isLoading = actionState.isLoading;

    return AuthScaffold(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthBrand(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Login',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Entre para gerenciar suas finanças com segurança.',
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
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                controller: _passwordController,
                label: 'Senha',
                validator: AuthValidators.requiredPassword,
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.push(AppRoutes.resetPassword),
                  child: const Text('Esqueceu a senha?'),
                ),
              ),
              if (actionState.message case final String message) ...<Widget>[
                AuthErrorMessage(
                  message: message,
                  isError: actionState.status == AuthActionStatus.failure,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AuthPrimaryButton(
                label: 'Entrar agora',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AuthDivider(),
              const SizedBox(height: AppSpacing.lg),
              AuthSocialButton(
                isLoading: isLoading,
                onPressed: isLoading
                    ? null
                    : ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthFooterLink(
                text: 'Não tem uma conta?',
                linkText: 'Cadastre-se',
                onPressed: () => context.push(AppRoutes.signUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
