import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

class InvestmentPremiumRouteGate extends ConsumerWidget {
  const InvestmentPremiumRouteGate({
    required this.capability,
    required this.intent,
    required this.child,
    this.fallbackLocation = AppRoutes.investments,
    super.key,
  });

  final PremiumCapability capability;
  final PremiumAccessIntent intent;
  final Widget child;
  final String fallbackLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InvestmentPremiumAccessState> access = ref.watch(
      investmentPremiumAccessControllerProvider,
    );
    return access.when(
      loading: () =>
          _PremiumAccessScaffold.loading(fallbackLocation: fallbackLocation),
      error: (Object _, StackTrace _) => _PremiumAccessScaffold.error(
        fallbackLocation: fallbackLocation,
        onRetry: () => ref
            .read(investmentPremiumAccessControllerProvider.notifier)
            .retry(),
      ),
      data: (InvestmentPremiumAccessState value) {
        final bool allowed = intent == PremiumAccessIntent.read
            ? value.canRead(capability)
            : value.canMutate(capability);
        if (allowed) return child;
        if (value.status == InvestmentPremiumAccessStatus.confirmationError) {
          return _PremiumAccessScaffold.error(
            fallbackLocation: fallbackLocation,
            message: value.safeMessage,
            onRetry: () => ref
                .read(investmentPremiumAccessControllerProvider.notifier)
                .retry(),
          );
        }
        if (intent == PremiumAccessIntent.mutate && value.canRead(capability)) {
          return _PremiumAccessScaffold.readOnly(
            fallbackLocation: fallbackLocation,
          );
        }
        return _PremiumAccessScaffold.denied(
          fallbackLocation: fallbackLocation,
          message: value.safeMessage,
          canRetry: value.problem == InvestmentPremiumAccessProblem.pending,
          onRetry: () => ref
              .read(investmentPremiumAccessControllerProvider.notifier)
              .retry(),
        );
      },
    );
  }
}

class _PremiumAccessScaffold extends StatelessWidget {
  const _PremiumAccessScaffold({
    required this.fallbackLocation,
    required this.icon,
    required this.title,
    required this.message,
    required this.semanticLabel,
    this.onRetry,
    this.loading = false,
  });

  factory _PremiumAccessScaffold.loading({required String fallbackLocation}) =>
      _PremiumAccessScaffold(
        fallbackLocation: fallbackLocation,
        icon: Icons.workspace_premium_outlined,
        title: 'Confirmando Premium',
        message: 'Aguarde enquanto confirmamos seu acesso com o servidor.',
        semanticLabel: 'Confirmando acesso Premium',
        loading: true,
      );

  factory _PremiumAccessScaffold.error({
    required String fallbackLocation,
    required Future<void> Function() onRetry,
    String message =
        'Não foi possível confirmar o Premium. Verifique sua conexão e tente novamente.',
  }) => _PremiumAccessScaffold(
    fallbackLocation: fallbackLocation,
    icon: Icons.cloud_off_outlined,
    title: 'Confirmação indisponível',
    message: message,
    semanticLabel: 'Confirmação Premium indisponível',
    onRetry: onRetry,
  );

  factory _PremiumAccessScaffold.readOnly({
    required String fallbackLocation,
  }) => _PremiumAccessScaffold(
    fallbackLocation: fallbackLocation,
    icon: Icons.lock_clock_outlined,
    title: 'Somente consulta',
    message:
        'Seu acesso Premium terminou. Seus dados continuam preservados e a carteira permanece disponível somente para consulta.',
    semanticLabel: 'Investimentos disponíveis somente para consulta',
  );

  factory _PremiumAccessScaffold.denied({
    required String fallbackLocation,
    required String message,
    required bool canRetry,
    required Future<void> Function() onRetry,
  }) => _PremiumAccessScaffold(
    fallbackLocation: fallbackLocation,
    icon: Icons.workspace_premium_outlined,
    title: 'Recurso Premium',
    message: message,
    semanticLabel: 'Acesso ao recurso Premium não disponível',
    onRetry: canRetry ? onRetry : null,
  );

  final String fallbackLocation;
  final IconData icon;
  final String title;
  final String message;
  final String semanticLabel;
  final Future<void> Function()? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => SafeBackScope(
    fallbackLocation: fallbackLocation,
    child: Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: fallbackLocation),
        title: const Text('Investimentos'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Semantics(
              container: true,
              label: semanticLabel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(icon, size: 44),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(message, textAlign: TextAlign.center),
                        if (loading) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          const CircularProgressIndicator(),
                        ],
                        if (onRetry != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => context.go(fallbackLocation),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: Text(
                            fallbackLocation == AppRoutes.investments
                                ? 'Voltar aos investimentos'
                                : 'Voltar',
                          ),
                        ),
                        if (title == 'Recurso Premium') ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          FilledButton.tonalIcon(
                            onPressed: () => context.push(AppRoutes.premium),
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('Conhecer Premium'),
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
      ),
    ),
  );
}
