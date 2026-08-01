import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transaction_action_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_view_support.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FinancialTransactionActionState>(
      financialTransactionActionControllerProvider,
      (
        FinancialTransactionActionState? previous,
        FinancialTransactionActionState next,
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
        });
      },
    );
    final AsyncValue<FinancialTransaction> transaction = ref.watch(
      financialTransactionDetailsProvider(transactionId),
    );
    final AsyncValue<FinancialWorkspace> workspace = ref.watch(
      financialWorkspaceProvider,
    );
    if (transaction.isLoading || workspace.isLoading) {
      return _loading();
    }
    if (transaction.hasError) {
      return _error(
        safeTransactionsErrorMessage(transaction.error!),
        () =>
            ref.invalidate(financialTransactionDetailsProvider(transactionId)),
      );
    }
    if (workspace.hasError) {
      return _error(
        safeTransactionsErrorMessage(workspace.error!),
        () => ref.invalidate(financialWorkspaceProvider),
      );
    }
    final FinancialTransactionActionState action = ref.watch(
      financialTransactionActionControllerProvider,
    );
    final FinancialTransaction? listedTransaction = workspace
        .requireValue
        .transactions
        .findById(transactionId);
    final FinancialTransaction? confirmedTransaction = action.transaction;
    final FinancialTransaction current =
        confirmedTransaction?.id == transactionId
        ? confirmedTransaction!
        : listedTransaction ?? transaction.requireValue;
    return _DetailsContent(
      transaction: current,
      workspace: workspace.requireValue,
    );
  }

  Widget _loading() => SafeBackScope(
    fallbackLocation: AppRoutes.transactions,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.transactions),
        title: const Text('Detalhes do lançamento'),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando detalhes do lançamento',
        ),
      ),
    ),
  );

  Widget _error(String message, VoidCallback onRetry) => SafeBackScope(
    fallbackLocation: AppRoutes.transactions,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.transactions),
        title: const Text('Detalhes do lançamento'),
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

class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({required this.transaction, required this.workspace});

  final FinancialTransaction transaction;
  final FinancialWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FinancialTransactionActionState action = ref.watch(
      financialTransactionActionControllerProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.transactions,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.transactions,
          ),
          title: const Text('Detalhes do lançamento'),
          actions: <Widget>[
            if (!transaction.isVoided)
              IconButton(
                tooltip: 'Editar lançamento',
                onPressed: action.isLoading
                    ? null
                    : () => context.push(
                        AppRoutes.editTransaction(transaction.id),
                      ),
                icon: const Icon(Icons.edit_outlined),
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
                    transactionKindIcon(transaction.kind),
                    size: 34,
                    semanticLabel: transaction.kind.label,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                transaction.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Tipo', value: transaction.kind.label),
              _DetailRow(
                label: 'Valor',
                value: MoneyFormatter.format(transaction.amount),
              ),
              _DetailRow(
                label: 'Conta',
                value: _accountName(transaction.accountId),
              ),
              _DetailRow(
                label: 'Categoria',
                value: _categoryName(transaction.categoryId),
              ),
              _DetailRow(
                label: 'Data',
                value: formatFinancialDate(transaction.occurredAt),
              ),
              _DetailRow(
                label: 'Observações',
                value: transaction.notes.isEmpty
                    ? 'Não informadas'
                    : transaction.notes,
              ),
              _DetailRow(
                label: 'Estado',
                value: transaction.isVoided
                    ? 'Cancelado — não participa do saldo'
                    : 'Ativo',
              ),
              _DetailRow(
                label: 'Criado em',
                value: formatFinancialDate(transaction.createdAt),
              ),
              _DetailRow(
                label: 'Última alteração',
                value: formatFinancialDate(transaction.updatedAt),
              ),
              if (transaction.isVoided) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Este lançamento foi cancelado e não participa do saldo. O cancelamento é irreversível.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: transaction.isVoided
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: action.isLoading
                      ? const Center(
                          heightFactor: 1,
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () => context.push(
                                AppRoutes.editTransaction(transaction.id),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar dados descritivos'),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () => _confirmVoid(context, ref),
                              icon: const Icon(Icons.block_outlined),
                              label: const Text('Cancelar lançamento'),
                            ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  String _accountName(String accountId) {
    for (final FinancialAccount account in workspace.accounts.accounts) {
      if (account.id == accountId) {
        return account.name;
      }
    }
    return 'Conta indisponível';
  }

  String _categoryName(String categoryId) {
    for (final FinancialCategory category in workspace.categories.categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return 'Categoria indisponível';
  }

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Cancelar este lançamento?'),
            content: const Text(
              'O lançamento deixará de participar do saldo, mas continuará registrado para preservar o histórico.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancelar lançamento'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(financialTransactionActionControllerProvider.notifier)
          .voidTransaction(transactionId: transaction.id);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
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
