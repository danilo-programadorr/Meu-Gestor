import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_action_state.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_components.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final AuthActionState actionState = ref.watch(authControllerProvider);
    final AsyncValue<FinancialSummary> financialSummary = ref.watch(
      financialSummaryProvider,
    );

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
                        'Seu acesso foi autenticado, o email está confirmado e '
                        'seu perfil está pronto para organizar contas e carteiras.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (environment ==
                          AppEnvironment.development) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        const Chip(label: Text('Ambiente de desenvolvimento')),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      financialSummary.when(
                        loading: () => const Card(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Carregando resumo financeiro',
                              ),
                            ),
                          ),
                        ),
                        error: (Object error, StackTrace stackTrace) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              children: <Widget>[
                                const Text(
                                  'Não foi possível confirmar o resumo financeiro.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      ref.invalidate(financialSummaryProvider),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (FinancialSummary summary) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Resumo financeiro',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _HomeSummaryRow(
                                  label: 'Total atual',
                                  value: MoneyFormatter.format(
                                    summary.totalCurrentBalance,
                                  ),
                                ),
                                _HomeSummaryRow(
                                  label: 'Receitas do mês',
                                  value: MoneyFormatter.format(
                                    summary.currentMonth.income,
                                  ),
                                ),
                                _HomeSummaryRow(
                                  label: 'Despesas do mês',
                                  value: MoneyFormatter.format(
                                    summary.currentMonth.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: <Widget>[
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                title: Text('Contas e carteiras'),
                                subtitle: Text(
                                  'Cadastre seus saldos iniciais sem dados de demonstração.',
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      context.push(AppRoutes.accounts),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('Ver contas'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push(AppRoutes.transactions),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Lançamentos'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.categories),
                            icon: const Icon(Icons.category_outlined),
                            label: const Text('Categorias'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push(AppRoutes.profile),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Abrir perfil'),
                      ),
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

class _HomeSummaryRow extends StatelessWidget {
  const _HomeSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );
}
