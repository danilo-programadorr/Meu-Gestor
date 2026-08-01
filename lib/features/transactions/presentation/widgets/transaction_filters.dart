import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

class TransactionFilters extends StatelessWidget {
  const TransactionFilters({
    required this.kind,
    required this.accountId,
    required this.categoryId,
    required this.currentMonthOnly,
    required this.accounts,
    required this.categories,
    required this.onKindChanged,
    required this.onAccountChanged,
    required this.onCategoryChanged,
    required this.onCurrentMonthChanged,
    super.key,
  });

  final FinancialTransactionKind? kind;
  final String? accountId;
  final String? categoryId;
  final bool currentMonthOnly;
  final List<FinancialAccount> accounts;
  final List<FinancialCategory> categories;
  final ValueChanged<FinancialTransactionKind?> onKindChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onCurrentMonthChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Todos'),
                selected: kind == null,
                onSelected: (_) => onKindChanged(null),
              ),
              ChoiceChip(
                label: const Text('Receitas'),
                selected: kind == FinancialTransactionKind.income,
                onSelected: (_) =>
                    onKindChanged(FinancialTransactionKind.income),
              ),
              ChoiceChip(
                label: const Text('Despesas'),
                selected: kind == FinancialTransactionKind.expense,
                onSelected: (_) =>
                    onKindChanged(FinancialTransactionKind.expense),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: accountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conta'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as contas'),
              ),
              ...accounts.map(
                (FinancialAccount account) => DropdownMenuItem<String?>(
                  value: account.id,
                  child: Text(account.name),
                ),
              ),
            ],
            onChanged: onAccountChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as categorias'),
              ),
              ...categories.map(
                (FinancialCategory category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Somente mês atual'),
            value: currentMonthOnly,
            onChanged: onCurrentMonthChanged,
          ),
        ],
      ),
    ),
  );
}
