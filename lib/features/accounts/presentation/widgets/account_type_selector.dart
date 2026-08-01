import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';

class AccountTypeSelector extends StatelessWidget {
  const AccountTypeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FinancialAccountType value;
  final ValueChanged<FinancialAccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<FinancialAccountType>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tipo',
        helperText: 'Escolha como esta conta ou carteira é utilizada.',
      ),
      items: FinancialAccountType.values
          .map(
            (FinancialAccountType type) =>
                DropdownMenuItem(value: type, child: Text(type.label)),
          )
          .toList(growable: false),
      onChanged: (FinancialAccountType? type) {
        if (type != null) {
          onChanged(type);
        }
      },
    );
  }
}
