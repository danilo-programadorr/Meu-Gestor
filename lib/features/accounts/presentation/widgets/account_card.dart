import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.account,
    required this.onTap,
    this.currentBalance,
    super.key,
  });

  final FinancialAccount account;
  final VoidCallback onTap;
  final Money? currentBalance;

  @override
  Widget build(BuildContext context) {
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
                  accountTypeIcon(account.type),
                  semanticLabel: account.type.label,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(account.type.label),
                    if (!account.includeInTotal) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      const Text('Não participa do total geral'),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    MoneyFormatter.format(
                      currentBalance ?? account.openingBalance,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    currentBalance == null ? 'Saldo inicial' : 'Saldo atual',
                  ),
                ],
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
