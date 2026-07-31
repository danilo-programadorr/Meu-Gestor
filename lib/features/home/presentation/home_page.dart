import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_components.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final AuthActionState actionState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Gestor Financeiro'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: actionState.isLoading
                ? null
                : ref.read(authControllerProvider.notifier).signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: 'Acesso autenticado e verificado',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Área autenticada',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Seu acesso foi autenticado e o email está confirmado. '
                        'Nenhum dado financeiro é carregado nesta etapa.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (environment ==
                          AppEnvironment.development) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        const Chip(label: Text('Ambiente de desenvolvimento')),
                      ],
                      if (actionState.message
                          case final String message) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        AuthErrorMessage(
                          message: message,
                          isError:
                              actionState.status == AuthActionStatus.failure,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
