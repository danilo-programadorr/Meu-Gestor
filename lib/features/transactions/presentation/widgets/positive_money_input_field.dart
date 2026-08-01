import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/positive_money_input_parser.dart';

class PositiveMoneyInputField extends StatelessWidget {
  const PositiveMoneyInputField({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
    ],
    decoration: const InputDecoration(
      labelText: 'Valor',
      prefixText: r'R$ ',
      hintText: '0,00',
      helperText: 'Informe um valor maior que zero.',
    ),
    validator: (String? value) {
      try {
        PositiveMoneyInputParser.parseBrlCents(value ?? '');
        return null;
      } on FinancialTransactionFailure catch (failure) {
        return failure.safeMessage;
      }
    },
    onEditingComplete: enabled
        ? () {
            try {
              final int cents = PositiveMoneyInputParser.parseBrlCents(
                controller.text,
              );
              controller.text = PositiveMoneyInputParser.formatEditable(cents);
            } on FinancialTransactionFailure {
              // O formulário apresenta a mensagem segura de validação.
            }
            FocusScope.of(context).unfocus();
          }
        : null,
  );
}
