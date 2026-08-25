import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/widgets/entity_action_icon_button.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_account_action_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

class AccountDetailsPage extends ConsumerWidget {
  const AccountDetailsPage({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FinancialAccountActionState>(
      financialAccountActionControllerProvider,
      (
        FinancialAccountActionState? previous,
        FinancialAccountActionState next,
      ) {
        if (previous?.status == next.status || next.message == null) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.message!)));
          if (next.status == FinancialAccountActionStatus.success) {
            context.go(
              next.account?.isArchived == true
                  ? AppRoutes.archivedAccounts
                  : AppRoutes.accounts,
            );
          }
        });
      },
    );
    final AsyncValue<FinancialAccount> accountState = ref.watch(
      financialAccountDetailsProvider(accountId),
    );
    return accountState.when(
      loading: () => SafeBackScope(
        fallbackLocation: AppRoutes.accounts,
        child: Scaffold(
          appBar: AppBar(
            leading: const SafeBackButton(fallbackLocation: AppRoutes.accounts),
            title: const Text('Detalhes da conta'),
          ),
          body: const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Carregando detalhes da conta',
            ),
          ),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => _DetailsError(
        message: safeAccountsErrorMessage(error),
        onRetry: () async {
          ref.invalidate(financialAccountDetailsProvider(accountId));
        },
      ),
      data: (FinancialAccount account) {
        final FinancialAccount? confirmed = ref
            .watch(financialAccountActionControllerProvider)
            .account;
        return _DetailsContent(
          account: confirmed?.id == account.id ? confirmed! : account,
        );
      },
    );
  }
}

class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FinancialAccountActionState action = ref.watch(
      financialAccountActionControllerProvider,
    );
    final AsyncValue<FinancialTransactionsState> transactions = ref.watch(
      financialTransactionsControllerProvider,
    );
    Money? currentBalance;
    final FinancialTransactionsState? transactionsValue = transactions.value;
    if (transactionsValue != null) {
      currentBalance = AccountBalanceCalculator.calculate(
        accounts: <FinancialAccount>[account],
        transactions: transactionsValue.transactions,
        now: ref.watch(financialClockProvider)(),
      ).balanceForAccount(account.id);
    }
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    return SafeBackScope(
      fallbackLocation: AppRoutes.accounts,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.accounts),
          title: const Text('Detalhes da conta'),
          actions: <Widget>[
            if (!account.isArchived)
              EntityActionIconButton(
                action: EntityActionIcon.edit,
                entityName: 'conta',
                onPressed: action.isLoading
                    ? null
                    : () => context.push(AppRoutes.editAccount(account.id)),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Center(
                child: CircleAvatar(
                  radius: 34,
                  child: Icon(
                    accountTypeIcon(account.type),
                    size: 34,
                    semanticLabel: account.type.label,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                account.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Tipo', value: account.type.label),
              _DetailRow(
                label: 'Saldo atual',
                value: currentBalance == null
                    ? 'Indisponível até confirmar os lançamentos'
                    : MoneyFormatter.format(currentBalance),
              ),
              _DetailRow(
                label: 'Saldo inicial',
                value: MoneyFormatter.format(account.openingBalance),
              ),
              const _DetailRow(label: 'Moeda', value: 'Real brasileiro (BRL)'),
              _DetailRow(
                label: 'Participa do total',
                value: account.includeInTotal ? 'Sim' : 'Não',
              ),
              _DetailRow(
                label: 'Estado',
                value: account.isArchived ? 'Arquivada' : 'Ativa',
              ),
              _DetailRow(
                label: 'Criada em',
                value: dateFormat.format(account.createdAt.toLocal()),
              ),
              _DetailRow(
                label: 'Última alteração',
                value: dateFormat.format(account.updatedAt.toLocal()),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'O saldo atual é derivado do saldo inicial e dos lançamentos ativos confirmados.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (action.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (account.isArchived)
                FilledButton.icon(
                  onPressed: () => ref
                      .read(financialAccountActionControllerProvider.notifier)
                      .setArchived(accountId: account.id, archived: false),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restaurar conta'),
                )
              else ...<Widget>[
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push(AppRoutes.editAccount(account.id)),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar conta'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _confirmArchive(context, ref),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arquivar conta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Arquivar esta conta?'),
            content: const Text(
              'Ela deixará de aparecer entre as contas ativas e de participar do total. '
              'Você poderá restaurá-la depois. Nenhum dado será apagado.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Arquivar'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(financialAccountActionControllerProvider.notifier)
          .setArchived(accountId: account.id, archived: true);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => SafeBackScope(
    fallbackLocation: AppRoutes.accounts,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.accounts),
        title: const Text('Detalhes da conta'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
