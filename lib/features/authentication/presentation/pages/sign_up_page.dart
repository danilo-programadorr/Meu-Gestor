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

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _showConsentError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool _validateFormAndConsent() {
    FocusScope.of(context).unfocus();
    final bool isFormValid = _formKey.currentState?.validate() == true;
    final bool hasConsent = _acceptedTerms && _acceptedPrivacy;
    setState(() => _showConsentError = !hasConsent);
    return isFormValid && hasConsent;
  }

  Future<void> _submit() async {
    if (!_validateFormAndConsent()) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .createAccount(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  Future<void> _submitGoogle() async {
    if (!_validateFormAndConsent()) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
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
                'Criar conta',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Configure sua conta para começar a gerenciar suas finanças.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthTextField(
                controller: _nameController,
                label: 'Nome completo',
                icon: Icons.person_outline_rounded,
                validator: AuthValidators.name,
                enabled: !isLoading,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
              ),
              const SizedBox(height: AppSpacing.md),
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
                validator: AuthValidators.strongPassword,
                enabled: !isLoading,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Use 8 ou mais caracteres, com letra maiúscula, minúscula e número.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthPasswordField(
                controller: _confirmationController,
                label: 'Confirmar senha',
                validator: (String? value) =>
                    AuthValidators.passwordConfirmation(
                      value,
                      _passwordController.text,
                    ),
                enabled: !isLoading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              _ConsentRow(
                value: _acceptedTerms,
                enabled: !isLoading,
                leadingText: 'Li e aceito os',
                linkText: 'Termos de Uso',
                onChanged: (bool value) =>
                    setState(() => _acceptedTerms = value),
                onLinkPressed: () => context.push(AppRoutes.terms),
              ),
              _ConsentRow(
                value: _acceptedPrivacy,
                enabled: !isLoading,
                leadingText: 'Li e aceito a',
                linkText: 'Política de Privacidade',
                onChanged: (bool value) =>
                    setState(() => _acceptedPrivacy = value),
                onLinkPressed: () => context.push(AppRoutes.privacy),
              ),
              if (_showConsentError) ...<Widget>[
                const AuthErrorMessage(
                  message:
                      'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (actionState.message case final String message) ...<Widget>[
                AuthErrorMessage(
                  message: message,
                  isError: actionState.status == AuthActionStatus.failure,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AuthPrimaryButton(
                label: 'Criar conta',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AuthDivider(label: 'Ou cadastre-se com'),
              const SizedBox(height: AppSpacing.lg),
              AuthSocialButton(
                isLoading: isLoading,
                onPressed: isLoading ? null : _submitGoogle,
              ),
              const SizedBox(height: AppSpacing.md),
              AuthFooterLink(
                text: 'Já tem uma conta?',
                linkText: 'Entrar',
                onPressed: () => context.go(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.enabled,
    required this.leadingText,
    required this.linkText,
    required this.onChanged,
    required this.onLinkPressed,
  });

  final bool value;
  final bool enabled;
  final String leadingText;
  final String linkText;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLinkPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Checkbox(
          value: value,
          onChanged: enabled
              ? (bool? selected) => onChanged(selected ?? false)
              : null,
          semanticLabel: '$leadingText $linkText',
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(leadingText, style: Theme.of(context).textTheme.bodyMedium),
              TextButton(
                onPressed: enabled ? onLinkPressed : null,
                child: Text(linkText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
