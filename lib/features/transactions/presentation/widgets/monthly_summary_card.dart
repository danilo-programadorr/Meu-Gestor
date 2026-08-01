import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';

class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({required this.summary, super.key});

  final MonthlyFinancialSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Resumo do mês atual',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(
            label: 'Receitas',
            value: MoneyFormatter.format(summary.income),
            icon: Icons.arrow_downward_rounded,
          ),
          _SummaryRow(
            label: 'Despesas',
            value: MoneyFormatter.format(summary.expense),
            icon: Icons.arrow_upward_rounded,
          ),
          const Divider(),
          _SummaryRow(
            label: 'Resultado',
            value: MoneyFormatter.format(summary.difference),
            icon: Icons.balance_outlined,
          ),
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: <Widget>[
        Icon(icon, semanticLabel: label),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
