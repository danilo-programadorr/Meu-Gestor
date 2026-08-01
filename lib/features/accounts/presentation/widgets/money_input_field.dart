import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/money_input_parser.dart';

class MoneyInputField extends StatelessWidget {
  const MoneyInputField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: const InputDecoration(
        labelText: 'Saldo inicial',
        prefixText: r'R$ ',
        hintText: '0,00',
        helperText: 'Use sinal negativo se a conta começar com saldo devedor.',
      ),
      validator: (String? value) {
        try {
          MoneyInputParser.parseBrlCents(value ?? '');
          return null;
        } on FinancialAccountFailure catch (failure) {
          return failure.safeMessage;
        }
      },
      onEditingComplete: () {
        try {
          final int cents = MoneyInputParser.parseBrlCents(controller.text);
          controller.text = MoneyInputParser.formatEditable(cents);
        } on FinancialAccountFailure {
          // A validação do formulário apresenta a mensagem segura.
        }
        FocusScope.of(context).unfocus();
      },
    );
  }
}
