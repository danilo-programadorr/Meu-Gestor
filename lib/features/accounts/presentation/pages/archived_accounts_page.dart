import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_account_action_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_card.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';

class ArchivedAccountsPage extends ConsumerWidget {
  const ArchivedAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FinancialAccountActionState>(
      financialAccountActionControllerProvider,
      (
        FinancialAccountActionState? previous,
        FinancialAccountActionState next,
      ) {
        if (previous?.status != next.status && next.message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(next.message!)));
            }
          });
        }
      },
    );
    final AsyncValue<FinancialAccountsState> accounts = ref.watch(
      financialAccountsControllerProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.accounts,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.accounts),
          title: const Text('Contas arquivadas'),
        ),
        body: SafeArea(
          child: accounts.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando contas arquivadas',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      safeAccountsErrorMessage(error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: ref
                          .read(financialAccountsControllerProvider.notifier)
                          .refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
            data: (FinancialAccountsState state) {
              if (state.archivedAccounts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Você não possui contas arquivadas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.archivedAccounts.length,
                itemBuilder: (BuildContext context, int index) {
                  final FinancialAccount account =
                      state.archivedAccounts[index];
                  final DateTime? archivedAt = account.archivedAt;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AccountCard(
                        account: account,
                        onTap: () =>
                            context.push(AppRoutes.accountDetails(account.id)),
                      ),
                      if (archivedAt != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'Arquivada em ${DateFormat('dd/MM/yyyy', 'pt_BR').format(archivedAt.toLocal())}',
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed:
                              ref
                                  .watch(
                                    financialAccountActionControllerProvider,
                                  )
                                  .isLoading
                              ? null
                              : () => ref
                                    .read(
                                      financialAccountActionControllerProvider
                                          .notifier,
                                    )
                                    .setArchived(
                                      accountId: account.id,
                                      archived: false,
                                    ),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Restaurar'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
