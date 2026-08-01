import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_view_support.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    required this.transaction,
    required this.accountName,
    required this.categoryName,
    required this.onTap,
    super.key,
  });

  final FinancialTransaction transaction;
  final String accountName;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String prefix = transaction.kind == FinancialTransactionKind.income
        ? '+'
        : '-';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                child: Icon(
                  transactionKindIcon(transaction.kind),
                  semanticLabel: transaction.kind.label,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('$categoryName · $accountName'),
                    Text(formatFinancialDate(transaction.occurredAt)),
                    if (transaction.isVoided)
                      const Text('Cancelado — não participa do saldo'),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$prefix${MoneyFormatter.format(Money.fromCents(transaction.amountCents))}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
