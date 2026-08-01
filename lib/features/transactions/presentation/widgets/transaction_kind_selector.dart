import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';

class TransactionKindSelector extends StatelessWidget {
  const TransactionKindSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final FinancialTransactionKind value;
  final bool enabled;
  final ValueChanged<FinancialTransactionKind> onChanged;

  @override
  Widget build(BuildContext context) =>
      SegmentedButton<FinancialTransactionKind>(
        segments: FinancialTransactionKind.values
            .map(
              (FinancialTransactionKind kind) => ButtonSegment(
                value: kind,
                icon: Icon(
                  kind == FinancialTransactionKind.income
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                ),
                label: Text(kind.label),
              ),
            )
            .toList(growable: false),
        selected: <FinancialTransactionKind>{value},
        onSelectionChanged: enabled
            ? (Set<FinancialTransactionKind> selection) {
                onChanged(selection.single);
              }
            : null,
      );
}
