import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_card.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/accounts_total_card.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FinancialAccountsState> accountsState = ref.watch(
      financialAccountsControllerProvider,
    );
    final AsyncValue<FinancialTransactionsState> transactionsState = ref.watch(
      financialTransactionsControllerProvider,
    );
    final AsyncValue<AccountsBalanceWorkspace> workspace = _combineWorkspace(
      accountsState: accountsState,
      transactionsState: transactionsState,
      now: ref.watch(financialClockProvider)(),
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Contas e carteiras'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Contas arquivadas',
              onPressed: () => context.push(AppRoutes.archivedAccounts),
              icon: const Icon(Icons.archive_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.newAccount),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar conta'),
        ),
        body: SafeArea(
          child: workspace.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando contas e carteiras',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => _AccountsError(
              message: safeAccountsErrorMessage(error),
              onRetry: () async {
                await Future.wait<void>(<Future<void>>[
                  ref
                      .read(financialAccountsControllerProvider.notifier)
                      .refresh(),
                  ref
                      .read(financialTransactionsControllerProvider.notifier)
                      .refresh(),
                ]);
              },
            ),
            data: (AccountsBalanceWorkspace data) => RefreshIndicator(
              onRefresh: () async {
                await Future.wait<void>(<Future<void>>[
                  ref
                      .read(financialAccountsControllerProvider.notifier)
                      .refresh(),
                  ref
                      .read(financialTransactionsControllerProvider.notifier)
                      .refresh(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  104,
                ),
                children: <Widget>[
                  AccountsTotalCard(
                    total: data.summary.totalCurrentBalance,
                    activeAccountCount: data.accounts.activeAccounts.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_done_outlined, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          data.accounts.isServerConfirmed &&
                                  data.transactions.isServerConfirmed
                              ? 'Lista confirmada pelo servidor'
                              : 'Dados locais — confirmação pendente',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (data.accounts.activeAccounts.isEmpty)
                    const _EmptyAccounts()
                  else ...<Widget>[
                    Text(
                      'Contas ativas',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final FinancialAccount account
                        in data.accounts.activeAccounts)
                      AccountCard(
                        account: account,
                        currentBalance: data.summary.balanceForAccount(
                          account.id,
                        ),
                        onTap: () =>
                            context.push(AppRoutes.accountDetails(account.id)),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.archivedAccounts),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(
                      'Contas arquivadas (${data.accounts.archivedAccounts.length})',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class AccountsBalanceWorkspace {
  const AccountsBalanceWorkspace({
    required this.accounts,
    required this.transactions,
    required this.summary,
  });

  final FinancialAccountsState accounts;
  final FinancialTransactionsState transactions;
  final FinancialSummary summary;
}

AsyncValue<AccountsBalanceWorkspace> _combineWorkspace({
  required AsyncValue<FinancialAccountsState> accountsState,
  required AsyncValue<FinancialTransactionsState> transactionsState,
  required DateTime now,
}) {
  if (accountsState.hasError) {
    return AsyncError<AccountsBalanceWorkspace>(
      accountsState.error!,
      accountsState.stackTrace ?? StackTrace.current,
    );
  }
  if (transactionsState.hasError) {
    return AsyncError<AccountsBalanceWorkspace>(
      transactionsState.error!,
      transactionsState.stackTrace ?? StackTrace.current,
    );
  }
  final FinancialAccountsState? accounts = accountsState.value;
  final FinancialTransactionsState? transactions = transactionsState.value;
  if (accounts == null || transactions == null) {
    return const AsyncLoading<AccountsBalanceWorkspace>();
  }
  return AsyncData<AccountsBalanceWorkspace>(
    AccountsBalanceWorkspace(
      accounts: accounts,
      transactions: transactions,
      summary: AccountBalanceCalculator.calculate(
        accounts: accounts.accounts,
        transactions: transactions.transactions,
        now: now,
      ),
    ),
  );
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              semanticLabel: 'Nenhuma conta cadastrada',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Você ainda não cadastrou nenhuma conta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Adicione sua primeira conta ou carteira para começar a organizar seus saldos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newAccount),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar conta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsError extends StatelessWidget {
  const _AccountsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
