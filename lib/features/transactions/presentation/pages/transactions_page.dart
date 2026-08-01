import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/monthly_summary_card.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_filters.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_view_support.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  FinancialTransactionKind? _kind;
  String? _accountId;
  String? _categoryId;
  bool _currentMonthOnly = true;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FinancialWorkspace> workspace = ref.watch(
      financialWorkspaceProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Lançamentos'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.newTransaction),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Novo lançamento'),
        ),
        body: SafeArea(
          child: workspace.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando lançamentos',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => _TransactionsError(
              message: safeTransactionsErrorMessage(error),
              onRetry: _refresh,
            ),
            data: _buildContent,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(FinancialWorkspace workspace) {
    final DateTime now = ref.watch(financialClockProvider)();
    final List<FinancialTransaction> filtered = workspace.transactions.filter(
      kind: _kind,
      accountId: _accountId,
      categoryId: _categoryId,
      currentMonthOnly: _currentMonthOnly,
      now: now,
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          104,
        ),
        children: <Widget>[
          MonthlySummaryCard(summary: workspace.summary.currentMonth),
          const SizedBox(height: AppSpacing.md),
          TransactionFilters(
            kind: _kind,
            accountId: _accountId,
            categoryId: _categoryId,
            currentMonthOnly: _currentMonthOnly,
            accounts: workspace.accounts.accounts,
            categories: workspace.categories.categories,
            onKindChanged: (FinancialTransactionKind? value) {
              setState(() {
                _kind = value;
                if (_categoryId != null) {
                  final FinancialCategory? selected = workspace.categories
                      .findById(_categoryId!);
                  if (selected != null &&
                      value != null &&
                      selected.kind != value.categoryKind) {
                    _categoryId = null;
                  }
                }
              });
            },
            onAccountChanged: (String? value) {
              setState(() => _accountId = value);
            },
            onCategoryChanged: (String? value) {
              setState(() => _categoryId = value);
            },
            onCurrentMonthChanged: (bool value) {
              setState(() => _currentMonthOnly = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: <Widget>[
              Icon(Icons.cloud_done_outlined, size: 18),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Dados confirmados pelo servidor')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filtered.isEmpty)
            _EmptyTransactions(
              hasAny: workspace.transactions.transactions.isNotEmpty,
            )
          else
            for (final FinancialTransaction transaction in filtered)
              TransactionCard(
                transaction: transaction,
                accountName: _accountName(
                  workspace.accounts.accounts,
                  transaction.accountId,
                ),
                categoryName: _categoryName(
                  workspace.categories.categories,
                  transaction.categoryId,
                ),
                onTap: () =>
                    context.push(AppRoutes.transactionDetails(transaction.id)),
              ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(financialAccountsControllerProvider.notifier).refresh(),
      ref.read(financialCategoriesControllerProvider.notifier).refresh(),
      ref.read(financialTransactionsControllerProvider.notifier).refresh(),
    ]);
    ref.invalidate(financialWorkspaceProvider);
  }

  static String _accountName(
    List<FinancialAccount> accounts,
    String accountId,
  ) {
    for (final FinancialAccount account in accounts) {
      if (account.id == accountId) {
        return account.name;
      }
    }
    return 'Conta indisponível';
  }

  static String _categoryName(
    List<FinancialCategory> categories,
    String categoryId,
  ) {
    for (final FinancialCategory category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return 'Categoria indisponível';
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.receipt_long_outlined,
            size: 56,
            semanticLabel: 'Nenhum lançamento encontrado',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasAny
                ? 'Nenhum lançamento corresponde aos filtros.'
                : 'Você ainda não registrou lançamentos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasAny
                ? 'Ajuste os filtros para consultar outros registros.'
                : 'Registre uma receita ou despesa que já aconteceu.',
            textAlign: TextAlign.center,
          ),
          if (!hasAny) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.newTransaction),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo lançamento'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TransactionsError extends StatelessWidget {
  const _TransactionsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
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
